from fastapi import APIRouter
from pydantic import BaseModel
from app.services.login import verify_person_creds
from app import models
from app.database import get_session
from app.services.registration import create_household
from app.services.login import login

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
class HouseholdLoginRequest(BaseModel):
    phone: str
    password: str

@router.post("/household/login")
def log_into_household(data: HouseholdLoginRequest):

    #try to login
    id = login(data.phone, data.password, models.Household)
    if not id:
        return {
            "status": "failure",
            "message": "phone number and password pair do not match",
        }

    #now that login is successful, we can return whatever data we want 
    #TODO: use the id to retrieve profile data and send it here
   
    return {
        "status": "ok",
        "message": f"Successfully logged into household {id}",
    }