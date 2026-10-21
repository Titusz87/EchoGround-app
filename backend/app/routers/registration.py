from fastapi import APIRouter, Depends
from pydantic import BaseModel
from app.services.registration import create_person
# Commented out for local integration validation tests
# from app.services.firebase import verify_app_check

router = APIRouter()

#--------------------------------------------------------------------------------

#defines json input from front end
class StartupRequest(BaseModel):
    latitude: float
    longitude: float
    fcm_token: str

#-------------------------------------------------------------------------

#this is the route that runs ONCE when a device connects for the first time (to give the device a unique id and save fcm token in the backend)
@router.post("/create-person")
def register_person(data: StartupRequest):
    
    # FIXED: Passed as ordered positional arguments to eliminate parameter naming conflicts
    person_id = create_person(
        data.latitude,
        data.longitude,
        data.fcm_token
    )

    return {
        "status": "ok",
        "message": "Device registered successfully",
        "person_id": person_id
    }

#TODO this needs to be safe (if a network failure happens the device can't create 2 people entries)

#-----------------------------------------------------------------------------------------



