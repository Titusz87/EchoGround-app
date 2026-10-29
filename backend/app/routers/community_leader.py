from fastapi import APIRouter
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.registration import create_community_leader
from app.routers.household import LoginRequest
from app.services.login import login
from app.services import db_helpers as db

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
        return {
            "status": "failure",
            "message": verification,
        }

    #now try to make the cl
    message = create_community_leader(data.id, data.first_name, data.phone, data.password, data.community_name)        
    if message is not True:
        return {"status": "failure", "message": message}

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
        return {
            "status": "failure",
            "message": "phone number and password pair do not match",
        }

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

        #verify community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            return {
                "status": "failure",
                "message": "Community leader id does not exist in db records",
                }

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

@router.put("/community-leader/validate-incidents")
def update_incidents_to_be_validated_by_community_leader(data: CommunityLeaderValidateIncidentRequest):
    with get_session() as session:

        #verify community leader exists
        community_leader = session.get(models.Community_Leader, data.id)
        if community_leader is None:
            return {
                "status": "failure",
                "message": "Community leader id does not exist in db records",
                }

        #first retrieve the incidents from the db using the inputted list
        incidents = db.get_rows_from_ids(session, models.Current_Incident, data.validated_incidents)

        #now, for each incident, include the communities name in the 'validated_by' list in the incident row
        for incident in incidents:
            #do this dumb logic again to make it safe
            validated_by = list(incident.validated_by or [])
            if community_leader.community_name not in validated_by:
                validated_by.append(community_leader.community_name)
                incident.validated_by = validated_by
        session.commit()

        return {
            "status": "ok",
            "message": f"updated {len(incidents)} incidents in the db to be validated by '{community_leader.community_name}'",
            }