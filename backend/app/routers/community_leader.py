from fastapi import APIRouter
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.registration import create_community_leader
from app.routers.household import LoginRequest
from app.services.login import login

#-----------------------------------------

router = APIRouter()

#-----------------------------------------------
#make a community leader
class CommunityLeaderCreationRequest(BaseModel):
    id: int
    fcm_token: str
    first_name: str
    phone: str
    password: str | None = None #password isn't required
    community_name: str

@router.post("/community-leader/create")
def register_community_leader(data: CommunityLeaderCreationRequest):

    verification = verify_person_creds(data.id, data.fcm_token)

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
        "message": f"Successfully logged into community leader '{row.first_name}'",
    }