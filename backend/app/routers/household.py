from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.create_records import create_household, create_emergency_report
from app.services.login import login
from app.services import db_helpers as db
from app.services import firebase

#-----------------------------------------

router = APIRouter()

#-----------------------------------------------
#create a household in the db
class HouseholdCreationRequest(BaseModel):
    id: int
    #NOTE we don't need this field any more, due to simplifying the application: "fcm_token: str"   
    last_name: str
    phone: str
    count: int | None = None #client can provide these value but it is not required
    password: str | None = None

@router.post("/household/create")
def register_household(data: HouseholdCreationRequest):

    verification = verify_person_creds(data.id)
    if verification is not True:
        raise HTTPException(status_code=404, detail=verification)

    #now try to make the household
    success = create_household(data.id, data.last_name, data.phone, data.count, data.password)        
    if not success:
        raise HTTPException(status_code=401, detail="Person id already has a household")

    return {
        "status": "ok",
        "message": f"Household created successfully with id {data.id} and last name {data.last_name}",
    }
#---------------------------------------------------------------------

#approves the login of household in the app
class LoginRequest(BaseModel):
    id: int
    password: str

@router.post("/household/login")
def log_into_household(data: LoginRequest):

    #try to login
    row = login(data.id, data.password, models.Household)
    if not row:
        raise HTTPException(status_code=401, detail="incorrect login details")

    #now that login is successful, we can return whatever data we want 
    #we don't need to return anything however, this job will be handled by the 'refresh' routes
   
    return {
        "status": "ok",
        "message": f"Successfully logged into '{row.last_name}' household",
    }

#---------------------------------------------------------------------

#get all the communities names for the household signup page in the UI 
@router.get("/household/get-community-names")
def get_all_community_names():
    with get_session() as session:
        
        #get all the community names with a db helper
        community_names = db.get_column(session, models.Community_Leader, "community_name")

    return {
            "status": "ok",
            "communities" : community_names
        }
    
#----------------------------------------------------------------------
#register a household to a community
class CommunityRegistrationRequest(BaseModel):
    id: int
    community_name: str
     
@router.patch("/household/register")
def register_household_to_community(data: CommunityRegistrationRequest):
    with get_session() as session:

        #default safety check to check the person exists
        verification = verify_person_creds(data.id)
        if verification is not True:
            raise HTTPException(status_code=404, detail=verification)

        #check that the household exits
        household = session.get(models.Household, data.id)
        if household is None:
            raise HTTPException(status_code=404, detail= f"id:{data.id} does not have a household")

        #attempt to retrieve the community name
        community_leader = db.get_db_rows_by_all_fields(session, models.Community_Leader, {"community_name": data.community_name}) #this returns a list
        if len(community_leader) == 0:
            raise HTTPException(status_code=404, detail= f"community name '{data.community_name}' not found in database")
        community_leader = community_leader[0]
            
        #we know this exists because the household is logged in by this point. but just in case...
        household = session.get(models.Household, data.id)
        if household is None:
            raise HTTPException(status_code=404, detail= f"id:{data.id} does not have a household")

        #check the household isn't already signed up, otherwise append the id
        if data.id in community_leader.community_members:
            raise HTTPException(status_code=404, detail= f"{household.last_name} household is already a member of {community_leader.community_name}")
 
        #safely add the id without duplicates
        #we need to do this to append to Postgres arrays
        members = list(community_leader.community_members or [])
        if data.id not in members:
            members.append(data.id)
            community_leader.community_members = members
        
        #finally, add the community leader id to the household row
        household.community_leader_id = community_leader.id
        session.commit()
        
        return {
            "status": "ok",
            "message" : f"{household.last_name} household successfully registered to '{community_leader.community_name}': containing {len(community_leader.community_members)} members" 
        }
#-------------------------------------------------------------------------------------------
#create a household emergency report that will be pushed immediately to all households, and to community leader for validation 
class EmergencyReportRegistrationRequest(BaseModel):
    id: int
    title: str = Field(min_length=1)
    location: str = Field(min_length=1)
    description: str = Field(min_length=1)
     
@router.post("/household/emergency-report")
def send_emergency_report_to_db(data: EmergencyReportRegistrationRequest):
    with get_session() as session:

        #default safety check to check the person exists
        verification = verify_person_creds(data.id) #data.fcm_token)
        if verification is not True:
             raise HTTPException(status_code=404, detail= verification)
               
        #check that the household exits. It should, because this route will be used on the household dashboard
        household = session.get(models.Household, data.id)
        if household is None:
            raise HTTPException(status_code=404, detail= f"id:{data.id} does not have a household")

        #now that we know there is a valid household, check whether it belongs to a community
        if household.community_leader_id is None:
            raise HTTPException(status_code=401, detail= f"household '{household.last_name}' does not belong to a community")

        #now we can create the actual report for the db
        report = create_emergency_report(data.id, household.community_leader_id, data.title, data.location, data.description)
        if report is None:
            raise HTTPException(status_code=404, detail= "Failed to submit emergency report")

        #now we send push notifications to both the community leader and the households in the community 
        community_leader = session.get(models.Community_Leader, household.community_leader_id)
        message = f"{data.title} has been reported to {community_leader.community_name}!"
        send_data = {"type": "Emergency Report", "title": data.title, "location": data.location, "description": data.description, "household name": household.last_name, "report id": str(report.id), "created": str(report.created)}

        #send community leader a push notification 
        pushed_to_leader = False
        if community_leader is not None:
            person = session.get(models.People, community_leader.id)
            pushed_to_leader = firebase.send_firebase_notification(f"New Emergency Report", message, person.fcm_token, send_data)

        #send all households in the community a push notification
        household_sent_count = 0
        for id in community_leader.community_members: 
            person = session.get(models.People, id)
            sent = firebase.send_firebase_notification(f"New Emergency Report", message, person.fcm_token, send_data)
            if sent:
                household_sent_count += 1

        community_members = len(community_leader.community_members)
        return {
            "status": "ok",
            "message0": (f"Sent emergency report '{data.title}' to {community_leader.first_name}" if pushed_to_leader
                else f"Failed to send emergency report '{data.title}' to {community_leader.first_name}"),
            "message1" : f"Sent emergency report '{data.title}' to {household_sent_count}/{community_members} community members in community '{community_leader.community_name}'"
        }

#-------------------------------------------------------------------------------------
#generic route that can request any required data for a UI refresh 
class HouseholdRefreshPageRequest(BaseModel):
    id: int

@router.post("/household/refresh-dashboard")
def refresh_stale_data_on_the_dashboard(data: HouseholdRefreshPageRequest):
    with get_session() as session:
        #default safety check to check the person exists
        verification = verify_person_creds(data.id) #data.fcm_token)
        if verification is not True:
                raise HTTPException(status_code=401, detail= verification)
                
        #check that the household exits. It should, because this route will be used on the household dashboard
        household = session.get(models.Household, data.id)
        if household is None:
            raise HTTPException(status_code=404, detail= f"id:{data.id} does not have a household")

        #now that we know there is a valid household, check whether it belongs to a community
        if household.community_leader_id is None:
            raise HTTPException(status_code=403, detail= f"household '{household.last_name}' does not belong to a community")

        #check the community leader exists
        community_leader = session.get(models.Community_Leader, household.community_leader_id)
        if community_leader is None:
            raise HTTPException(status_code=404, detail= f"community leader value in household was incorrectly set")

        #------------now, we can pull any data from the server that we want:----------------------

        #retrieve number of community members
        members_count = 0
        for id in community_leader.community_members:
            member_household = session.get(models.Household, id)
            if member_household is not None:
                members_count += member_household.count

        #retrieve community plans. the below fn returns a list  
        community_plans_rows = db.get_db_rows_by_all_fields(session, models.Community_Posts, {"community_leader_id": community_leader.id, "post_type": "plans"})
        community_plans = ""
        if community_plans_rows:
            community_plans = community_plans_rows[0]
            community_plans = community_plans.data
        
        return {
            "status": "ok",
            "message": "pulled necessary data for household dashboard from servers",
            "data": {"community name": community_leader.community_name,
                     "community leader name": community_leader.first_name,
                     "community households count": len(community_leader.community_members or []),
                     "community members count": members_count,
                     "community plans": community_plans
                     } 
        }