from app import models
from app.database import get_session
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
import app.services.db_helpers as db
from app.services.quadtree import Quadtree
import numpy as np
from sklearn.neighbors import BallTree
from app.services.firebase import send_firebase_notification

#------------------script vars-----------------------
quadtree = None
UNSAFE_BUSHFIRE_DISTANCE = 30

#---------------------config---------------------------------

verbose_debug = False
custom_quadtree = False
notification_fields  = ["status", "warning_level", "latitude", "longitude", "description", "address"] #people get updated when these fields change
push_user_notifications = True
print_user_notifications = True
stale_incident_time_days = 1   

#-------------------------------info-----------------------------------------

possible_warning_levels = ['advice', 'none', 'watch_and_act']
possible_statuses = ['completed', 'safe', 'active', 'controlled', 'contained']
example_incidents = ['burn_off', 'hazmat', 'bushfire', 'structure_fire', 'medical', 'vehicle_fire', 'rescue', 'grass_fire', 'flood', 'earthquake', 'vehicle_accident', 'storm', 'other', 'other_fire', 'alarm', 'tree_down']

#--------------------------fn's called from other scripts-----------------------------------------------

#this fn is called from the polling script
#this is complicated. Please don't touch it!
def update_database_incidents(incidents):
    with get_session() as session:
        
        print("Updating db records...")

        #------------------------insert polled incidents in temporary_incidents table-------------------------    
        
        #need to turn our incidents class into proper table objects before writing them to db
        #we need to compare the ids of things because they are unique (objects may not be)
        #we need to store the new incidents in a temporary table for logic later (temporary_incidents should be empty-> it is flushed at the end of this fn)
        temporary_incidents = db.convert_incidents_orm_objects(incidents, models.Temporary_Incident) 
        db.write_list_to_db(session, temporary_incidents)          
        print(f"Added {len(temporary_incidents)} new incidents to temporary_incidents")
        print_incidents_info(session)

        #---------------------------Add the new incidents to current_incidents table----------------------------------

        #we now insert the incidents that are actually new into the current_incidents (not old ones that have been updated)
        #we need to check the archived table to make sure that the expired/completed incidents aren't being written to current_incidents then archived over and over again...
        #this is because the expired and completed incidents are still pulled from dataquolls API each time it polls.
        #so because the incidents that were archived (due to being expired or completed) were removed from current_incidents in the last poll...
        #they are treated as new incidents here. This means that before we insert the new incidents, we need to filter the ones that are in the archived table
        current_incident_ids = db.get_ids_from_table(session, models.Current_Incident) or []
        temporary_incident_ids = db.get_ids_from_table(session, models.Temporary_Incident) or []
        archived_incidents_ids = db.get_ids_from_table(session, models.Archived_Incident) or []
        new_incidents_ids = get_new_ids_safe(current_incident_ids, temporary_incident_ids)
        filtered_incident_ids = set(new_incidents_ids) - set(archived_incidents_ids)
        insert_incidents = db.get_rows_from_ids(session, models.Temporary_Incident, filtered_incident_ids)
        insert_incidents = db.convert_incidents_orm_objects(insert_incidents, models.Current_Incident)
        db.write_list_to_db(session, insert_incidents)
        print(f"Added {len(insert_incidents)} new incidents to current_incidents")
        db.print_table_info(session, models.Current_Incident)

        #--------------------------Find incidents that have been updated and write updates to current_incidents-----------------------------
        
        #we can now check whether any fields have been updated from 'current_incidents' using common_incident_ids
        #incident updates are a nested dictionary like this -> { id: { field: new status } }  
        global notification_fields  
        common_incidents_ids = set(temporary_incident_ids) & set(current_incident_ids)
        current_incident_updates = current_incidents_changed_values(session, common_incidents_ids, notification_fields)
        print(f"{len(current_incident_updates)} incidents have changed statues to inform users")
        if verbose_debug:
            print(f"Updated incidents: {current_incident_updates}")
        update_incident_table(session, models.Current_Incident, current_incident_updates) 

        #--------------------------Update incidents with timestamp updates. Find completed or expired incidents-----------------------

        #many incidents will also have an updated 'last_updated' value which also needs to be written
        timestamp_updates = current_incidents_changed_values(session, common_incidents_ids, ["last_updated"])
        update_incident_table(session, models.Current_Incident, timestamp_updates)
        print(f"{len(timestamp_updates)} incidents have had timestamp updates") 
        
        expired_incidents = get_expired_incidents(session, models.Current_Incident)
        completed_incidents = db.get_db_rows_by_all_fields(session, models.Current_Incident, {"status": "completed"})
        expired_incident_ids = [incident.id for incident in expired_incidents] 
        completed_incident_ids = [incident.id for incident in completed_incidents]
        remove_incidents_ids = set(expired_incident_ids) | set(completed_incident_ids)
        print(f"{len(expired_incidents)} incidents have expired")
        print(f"{len(completed_incidents)} incidents have 'completed' status")
        
        #---------------------------Safely add new expired and completed incidents to archived_incidents------------------------- 
        
        #figure out which incidents need to be archived (where ids don't already exist in archived_incidents)
        existing_archived_ids = db.get_ids_from_table(session, models.Archived_Incident)
        new_archived_ids = get_new_ids_safe(existing_archived_ids, remove_incidents_ids)
        new_archived_incidents = db.get_rows_from_ids(session, models.Current_Incident, new_archived_ids)
        new_archived_incidents = db.convert_incidents_orm_objects(new_archived_incidents, models.Archived_Incident) 
        db.write_list_to_db(session, new_archived_incidents)
        print(f"Archived {len(new_archived_incidents)} incidents")


        #----------------------Create quadtree for incident lookup. Update people_incidents table---------------
        
        #now the current incidents have been rewritten, create quadtree for nearby incident lookup and rewrite table
        #nearby_incident_data is { person_id : [list of incidents] }
        nearby_incident_data = use_quadtree(session)
        people_to_incident_rows = db.get_all_rows(session, models.People_Incident)
        for row in people_to_incident_rows: 
            row.incident_ids = nearby_incident_data.get(row.id)
        #db.write_list_to_db(session, people_to_incident_rows)        
        nearby_incident_count = sum(1 for person_id, incident_ids in nearby_incident_data.items() if incident_ids)
        print(f"{nearby_incident_count} people have nearby incidents occurring")

        #--------------------Search nearby_incident_data to send users updates-------------------------------- 

        #at the moment this only updates the user if the 'notification_fields' have been changed
        #we may want to later update the user if the incident has expired. However, we probably won't need to 
        #we don't need to update them whether the incident has completed, because 'completed' is a 'status' which is included in notification_field
        
        #incident updates are a nested dictionary like this -> { incident_id: { field: new status } }
        #nearby_incident_data is { person_id : [list of incidents] }
        if push_user_notifications:
            push_data = create_user_notification_data(nearby_incident_data, current_incident_updates)
            people_with_updates_count =  people_with_updates_count = sum(bool(incidents) for incidents in push_data.values())
            print(f"{people_with_updates_count} out of {len(db.get_all_rows(session, models.People))} people have incident updates")
            notify_users(session, push_data)

        
        #------------------Cleanup: flush temporary_incidents and delete archived incidents from current_incidents-----
        
        #can delete the rows in current_incidents that were archived now
        remove_incidents = db.get_rows_from_ids(session, models.Current_Incident, remove_incidents_ids)
        db.delete_db_rows(session, remove_incidents)
        print(f"Removed {len(remove_incidents)} incidents from current_incidents")

        #we are done with temp table. Print table info and commit
        db.flush_db_table(session, models.Temporary_Incident)
        print_incidents_info(session)
        session.commit()


#------------------------------helpers------------------------------------------------------------

#This can be pushed to users
def get_expired_incidents(session, model):
    check = db.get_all_rows(session, model)
    expired = []
    time_now = datetime.now(timezone.utc)
    stale_incident_count = 0

    for incident in check:
        stale_incident = False
        if incident.expires is None:
            #check against our created value
            expiry_time = incident.created + timedelta(days = stale_incident_time_days)
            stale_incident = True
        else:
            expiry_time = incident.expires
        
        if expiry_time.tzinfo is None:
            expiry_time = expiry_time.replace(tzinfo=timezone.utc)
        if expiry_time < time_now:
            expired.append(incident)
            if stale_incident:
                stale_incident_count += 1

    print(f"{stale_incident_count} incidents without provided expiry times have gone stale (Expiry Time: f{stale_incident_time_days})")
    return expired

#check for status/warning level changes
def current_incidents_changed_values(session, checklist_ids, check_fields):
    updated = {}

    #get the rows from the 2 tables to be checked for updates
    old_incidents = db.get_rows_from_ids(session, models.Current_Incident, checklist_ids) 
    new_incidents = db.get_rows_from_ids(session, models.Temporary_Incident, checklist_ids)

    #create 2 dictionaries for easy look up and comparison
    old_incident_by_id = {}
    for incident in old_incidents:
        old_incident_by_id[incident.id] = incident
    new_incident_by_id = {}
    for incident in new_incidents:
        new_incident_by_id[incident.id] = incident

    #compare fields
    for id, old_incident in old_incident_by_id.items():
        new_incident = new_incident_by_id[id]
        changed_fields = {}

        for field in check_fields:
            old_value = getattr(old_incident, field)
            new_value = getattr(new_incident, field)
            if old_value != new_value:
                changed_fields[field] = new_value

        if changed_fields:
            updated[id] = changed_fields

    return updated

def update_incident_table(session, model, updates):
    #extract the rows to update by their ids (the keys from updates)
    updated_rows = db.get_rows_from_ids(session, model, list(updates))

    #remember updates are like this -> { id: { field: new status } }
    for row in updated_rows:
        updated_fields = updates[row.id]
        
        for field, new_value in updated_fields.items():
            setattr(row, field, new_value)

def print_incidents_info(session):
    db.print_table_info(session, models.Temporary_Incident)
    db.print_table_info(session, models.Current_Incident)
    db.print_table_info(session, models.Archived_Incident)

def get_new_ids_safe(old_ids, new_ids):
    old_ids = set(old_ids or [])
    new_ids = set(new_ids or [])
    return new_ids - old_ids

def use_quadtree(session):
    current_incident_rows = db.get_all_rows(session, models.Current_Incident)
    people = db.get_all_rows(session, models.People) or []
    if len(people) == 0:
        return {}
    results = {}
    print("Spatially partitioning incidents for user location updates...")
    
    if custom_quadtree:
        #extract only relevant data    
        incident_points = [Quadtree.IncidentPoint(row.latitude, row.longitude, row.id) for row in current_incident_rows]
        global quadtree
        quadtree = Quadtree(incident_points)

        #people need to 'subscribe' to nearby incidents 
        #get nearby incidents for all people via the quadtree
        print("Finding incidents nearby to people in db...")
        people_locations = [Quadtree.IncidentPoint(person.latitude,person.longitude,person.id) for person in people]
        results = {person.id: [] for person in people_locations}
        for person in people_locations:
            found_incidents = quadtree.find_nearby_incidents(person,UNSAFE_BUSHFIRE_DISTANCE)
            results[person.id] = [incident.id for incident in found_incidents]
    else:
        #this is the solution from a balltree library 
        incident_coords = np.radians([[row.latitude, row.longitude] for row in current_incident_rows])
        people_coords = np.radians([[person.latitude, person.longitude] for person in people])
        tree = BallTree(incident_coords, metric="haversine")
        radius_radians = UNSAFE_BUSHFIRE_DISTANCE / 6371.0
        results_indices = tree.query_radius(people_coords, r=radius_radians)
        for person, incident_indices in zip(people, results_indices):
            results[person.id] = [current_incident_rows[i].id for i in incident_indices]

    if verbose_debug:
        print(results)
    return results

def create_user_notification_data(people_to_incident_data, incident_updates):
    updated_incident_ids = list(incident_updates)
    result = {}
    for person_id, incident_list in people_to_incident_data.items():
        push_ids = set(incident_list) & set(updated_incident_ids)
        result[person_id] = list(push_ids)
    return result

#make sure this function isn't called before the archived incidents are deleted from current_incidents
#incidents may have been updated and then expired. The user still needs to be informed
def notify_users(session, push_data):

    #get all the possible notifications that can be sent to people
    all_incident_ids = set()
    for person_id, incident_list in push_data.items():
        for incident in incident_list:
            all_incident_ids.add(incident)
    all_notification_rows = db.get_rows_from_ids(session, models.Current_Incident, all_incident_ids)

    #now push data to each person 
    sent_messages = 0
    for person_id, incident_ids in push_data.items():
        status = notify_user(session, person_id, incident_ids, list(all_notification_rows))
        if status:
            sent_messages += status
    print(f"Pushed {sent_messages} notifications to users")
        
def notify_user(session, person_id, incident_ids, from_rows):
    
    #if there's no fcm token then don't bother sending a message
    fcm_token = db.get_value_by_id(session, models.People, person_id, "fcm_token")
    if not fcm_token:
        return False 
    
    #now extract only the rows we need and send messages
    message_rows = [row for row in from_rows if row.id in incident_ids]
    sent_messages = 0
    global print_user_notifications
    for row in message_rows:
        try:
            data = row_to_firebase_data(row)
            message = create_message_from_incident(row)
            send_firebase_notification("New Incident Update", message, fcm_token, data)
            if print_user_notifications:
                print(f"Notification to user: {message}")
            sent_messages += 1 
        except Exception as e:
            print(f"Failed to send notification: {e}")
    return sent_messages

def row_to_firebase_data(row):
    return {column.name: str(getattr(row, column.name) or "") for column in row.__table__.columns}

def create_message_from_incident(row):
    message = f"There is a {row.event_type} near you with status '{row.status}' and warning level '{row.warning_level}. "

    #these fields from dataquoll can be blank  >:(
    if row.description is not None:
        message = message + row.description
    if row.address is not None:
        message = message + row.address
    
    return "message"
