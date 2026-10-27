from fastapi import APIRouter
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.registration import create_community_leader

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

@router.post("/community-leader/create")
def register_community_leader(data: CommunityLeaderCreationRequest):

    verification = verify_person_creds(data.id, data.fcm_token)

    if verification is not True:
        return {
            "status": "failure",
            "message": verification,
        }

    #now try to make the cl
    success = create_community_leader(data.id, data.first_name, data.phone, data.password)        
    if not success:
        return {"status": "failure", "message": "Person id already is a community leader"}

    return {
        "status": "ok",
        "message": f"Community Leader created successfully with id {data.id} and name {data.first_name}",
    }
#---------------------------------------------------------------------