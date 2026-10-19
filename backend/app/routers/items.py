from app import models
from app.database import get_session
from sqlalchemy.orm import Session
from sqlalchemy import delete

#open a session and write an object to the household table 
def create_household():
    #make a session 
    with get_session() as session:
        user = models.Community_Leader()
        session.add(user)
        session.commit()

def write_incidents_to_db(incidents):
    #need to turn our incidents class into proper table objects before writing them to db
    current_incidents = translate_incident_objects_to_table_objects(incidents)

    #open session and write members of list to db
    with get_session() as session:
        session.add_all(current_incidents)
        session.commit()
    print("Successfully wrote polled incidents to db")

#convert incidents between our python class and table class 
def translate_incident_objects_to_table_objects(incidents):
    translated = []
    for incident in incidents:
        current_incident = models.Current_Incident(
            id = incident.id,
            event_type = incident.event_type,
            status = incident.status, 
            warning_level = incident.warning_level, 
            state = incident.state,
            latitude = incident.latitude, 
            longitude = incident.longitude, 
            reported_time = incident.reported_time,
            last_updated = incident.last_updated,
            expires = incident.expires,
            description = incident.description, 
            address = incident.address
        )
        translated.append(current_incident)
    return translated

#use this code to delete rows (not the table itself)
# with get_session() as session:
#     session.execute(delete(models.Current_Incident))
#     session.commit() 