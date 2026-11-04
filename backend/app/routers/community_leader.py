from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.create_records import create_community_leader, create_community_plans
from app.routers.household import LoginRequest
from app.services.login import login
from app.services import db_helpers as db
from app.services import firebase

#-----------------------------------------

router = APIRouter()

#-----------------------------------------------
#make a community leader
class CommunityLeaderCreationRequest(BaseModel):
    id: int
    #fcm_token: str
    first_name: str
    phone: str
    password: str | None = None #password isn't required
    community_name: str

@router.post("/community-leader/create")
def register_community_leader(data: CommunityLeaderCreationRequest):

    verification = verify_person_creds(data.id)#, data.fcm_token)
    if verification is not True:
        raise HTTPException(status_code=401, detail= verification)

    #now try to make the cl
    message = create_community_leader(data.id, data.first_name, data.phone, data.password, data.community_name)        
    if message is not True:
        raise HTTPException(status_code=401, detail= message)

    return {
        "status": "ok",
        "message": f"Community Leader created successfully with id {data.id} and community name {data.community_name}",
    }
#---------------------------------------------------------------------

#this fn is identical to the household login version
@router.post("/community-leader/login")
def log_into_community_leader(data: LoginRequest):

    #try to login
    row = login(data.id, data.password, models.Community_Leader)
    if not row:
        raise HTTPException(status_code=401, detail= "phone number and password pair do not match")

    #now that login is successful, we can return whatever data we want 
    #TODO: use the id to retrieve profile data and send it here
   
    return {
        "status": "ok",
        "message": f"Successfully logged into community leader '{row.first_name}'"
    }

#--------------------------------------------------------------------
#get all the incidents for a community leader to validate
class CommunityLeaderIncidentRequest(BaseModel):
    id: int

@router.post("/community-leader/get-incidents")
def get_all_incidents_affecting_the_community(data:CommunityLeaderIncidentRequest):
    with get_session() as session:

        #verify id exists
        verification = verify_person_creds(data.id)
        if verification is not True:
            raise HTTPException(status_code=401, detail= verification)

        #verify community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            raise HTTPException(status_code=404, detail= "Community leader id does not exist in db records")

        #retrieve the list of ids (people)
        community_member_ids = db.get_value_by_id(session, models.Community_Leader, community_leader.id, "community_members")

        #then, get the list of incidents from people_incidents table with the people ids
        #make sure the list is unique 
        community_incident_ids = set()
        for id in community_member_ids:
            incident_list = db.get_value_by_id(session, models.People_Incident, id, "incident_ids")
            if incident_list is None:
                continue
            for incident in incident_list:
                community_incident_ids.add(incident)

        #then send all those incidents back
        community_incidents = db.get_rows_from_ids(session, models.Current_Incident, list(community_incident_ids))
        return {
            "status": "ok",
            "message": f"retrieved {len(community_incidents)} incidents affecting the community '{community_leader.community_name}': containing {len(community_member_ids)} members",
            "community_incidents": community_incidents 
            }

#---------------------------------------------------------------------------------------------
#rewrite incident ORM objects to have been validated by a community leader
class CommunityLeaderValidateIncidentRequest(BaseModel):
    id: int
    validated_incidents: list[str]
    notice: str | None = None

@router.put("/community-leader/validate-incidents")
def update_incidents_to_be_validated_by_community_leader(data: CommunityLeaderValidateIncidentRequest):
    with get_session() as session:

        #verify id exists
        verification = verify_person_creds(data.id)
        if verification is not True:
            raise HTTPException(status_code=401, detail= verification)

        #verify community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            raise HTTPException(status_code=404, detail= "Community leader id does not exist in db records")

        #first retrieve the incidents from the db using the inputted list
        incidents = db.get_rows_from_ids(session, models.Current_Incident, data.validated_incidents)

        #now, for each incident, include the communities name in the 'validated_by' dictionary in the incident row
        #optionally, include a 'notice' as the value in the dict 
        for incident in incidents:
            #do this dumb logic again to make it safe
            validated_by = dict(incident.validated_by or {})
            if community_leader.community_name not in list(validated_by):
                validated_by[community_leader.community_name] = data.notice
                incident.validated_by = validated_by
        session.commit()

        return {
            "status": "ok",
            "message": f"updated {len(incidents)} incidents in the db to be validated by '{community_leader.community_name}' with notice '{data.notice}'"
            }

#------------------------------------------------------------------------------------------------

class CommunityLeaderPlanCreationRequest(BaseModel):
    id: int
    body: str
    
@router.post("/community-leader/create-community-plans")
def create_community_specific_plans(data: CommunityLeaderPlanCreationRequest):
    with get_session() as session:

        #verify id exists
        verification = verify_person_creds(data.id)
        if verification is not True:
            raise HTTPException(status_code=401, detail= verification)

        #check community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            raise HTTPException(status_code=404, detail= "Community leader id does not exist in db records")

        #now, we can submit the plans 
        create_community_plans(community_leader.id, community_leader.community_name, data.body)
        return {
            "status": "ok",
            "message": f"created community plans for {community_leader.community_name}"
            }

class CommunityLeaderPublishNotificationRequest(BaseModel):
    id: int
    body: str

@router.post("/community-leader/publish-notification")
def send_a_notification_to_all_community_members(data: CommunityLeaderPublishNotificationRequest):
    with get_session() as session:

        #verify id exists
        verification = verify_person_creds(data.id)
        if verification is not True:
            raise HTTPException(status_code=401, detail= verification)

        #check community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            raise HTTPException(status_code=404, detail= "Community leader id does not exist in db records")
    
        #now that we know everything is ok, we can send a firebase message to everyone in the community
        #retrieve all the fcm tokens
        person_rows = db.get_rows_from_ids(session, models.People, community_leader.community_members)
        sent_count = 0
        for person in person_rows:
            success = firebase.send_firebase_notification(f"New community notification from {community_leader.first_name}", data.body, person.fcm_token)
            if success:
                sent_count += 1
        return {
            "status": "ok",
            "message": f"Sent {sent_count} notifications to community members in '{community_leader.community_name}'"
            }