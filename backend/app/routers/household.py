from fastapi import APIRouter
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.registration import create_household
from app.services.login import login
from app.services import db_helpers as db

#-----------------------------------------

router = APIRouter()

#-----------------------------------------------
#make a household
class HouseholdCreationRequest(BaseModel):
    id: int
    fcm_token: str
    last_name: str
    phone: str
    count: int | None = None #client can provide these value but it is not required
    password: str | None = None

@router.post("/household/create")
def register_household(data: HouseholdCreationRequest):

    verification = verify_person_creds(data.id, data.fcm_token)
    if verification is not True:
        return {
            "status": "failure",
            "message": verification,
        }

    #now try to make the household
    success = create_household(data.id, data.last_name, data.phone, data.count, data.password)        
    if not success:
        return {"status": "failure", "message": "Person id already has a household"}

    return {
        "status": "ok",
        "message": f"Household created successfully with id {data.id} and last name {data.last_name}",
    }
#---------------------------------------------------------------------
#log in to household
class LoginRequest(BaseModel):
    id: int
    password: str

@router.post("/household/login")
def log_into_household(data: LoginRequest):

    #try to login
    row = login(data.id, data.password, models.Household)
    if not row:
        return {
            "status": "failure",
            "message": "phone number and password pair do not match",
        }

    #now that login is successful, we can return whatever data we want 
    #TODO: use the id to retrieve profile data and send it here
   
    return {
        "status": "ok",
        "message": f"Successfully logged into '{row.last_name}' household",
    }

#---------------------------------------------------------------------
#get all the communities so the household can join one 
@router.get("/household/get-community-names")
def get_all_community_names():
    with get_session() as session:
        
        #get all the community names with db helper
        community_names = db.get_column(session, models.Community_Leader, "community_name")

    return {
            "status": "ok",
            "communities" : community_names
        }
    
#----------------------------------------------------------------------
class CommunityRegistrationRequest(BaseModel):
    id: int
    community_name: str
    
#register a household to a community 
@router.patch("/household/register")
def register_household_to_community(data: CommunityRegistrationRequest):
    with get_session() as session:
        #we know that the community name must exist because the front end received a list of all the names
        #this would be a problem if community leaders could be deleted, but for the prototype we aren't implementing this

        #the community names are also unique due to the way they are created
        community_leader = db.get_db_rows_by_all_fields(session, models.Community_Leader, {"community_name": data.community_name}) #this returns a list
        if len(community_leader) == 0:
            return{
                    "status": "failure",
                    "message" : f"community name {data.community_name} not found in database"
            }
        community_leader = community_leader[0]
            
        #we know this exists because the household is logged in by this point. 
        household = session.get(models.Household, data.id)

        #check the household isn't already signed up, otherwise append the id
        if data.id in community_leader.community_members:
            return {
                "status": "failure",
                "message" : f"{household.last_name} household is already a member of {community_leader.community_name}"
            }

        community_leader.community_members.append(data.id)
        session.commit()
        return {
            "status": "ok",
            "message" : f"{household.last_name} household successfully registered to {community_leader.community_name}" 
        }

        

        

    


