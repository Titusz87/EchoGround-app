from fastapi import APIRouter
from pydantic import BaseModel

#-----------------------------------------

router = APIRouter()

#-----------------------------------------------

#receive the users id and fcm token to verify their location update
class LocationUpdateRequest(BaseModel):
    latitude: float
    longitude: float
    id: int
    fcm_token: str

#------------------------------------------------------------

#TODO log in to user




#TODO log into admin 

#---------------------------------------------------------------

#the PATCH that updates location of a person 
@router.patch("/person/update-location")
def update_location(data: LocationUpdateRequest):
    #TODO: retrieve user from people table, rewrite their location data


    return {
        "status": "ok",
        "message": "Location updated successfully",
    }