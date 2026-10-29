from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, ConfigDict
from app.services.registration import create_person
from app.database import get_session
from app import models
from app.services.login import verify_person_creds
from datetime import datetime
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
@router.post("/person/create")  #changed from /create-person to /person/create to match the frontend request path
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


#-----------------------------------------------------------------------------------------
#receive the users id and fcm token to verify their location update
class LocationUpdateRequest(BaseModel):
    latitude: float
    longitude: float
    id: int
    fcm_token: str
#the PATCH that updates location of a person 
@router.patch("/person/update-location")
def update_location(data: LocationUpdateRequest):
    
    status = verify_person_creds(data.id, data.fcm_token)
    if status is True:
        with get_session() as session:
            person = session.get(models.People, data.id)
            person.latitude = data.latitude
            person.longitude = data.longitude
            session.commit()
        return {
            "status": "ok",
            "message": f"Location of person {data.id} updated successfully",
        }

    return {
        "status": "failure",
        "message": f"{status}",
    }
    
    
   
#----------------------------------------------------------------------------------



# ADDED: This is the route that runs to grab all active hazards standing near a specific device index block
# NOTE: this endpoint is used by the frontend dashboard view to fetch and plot 
# a complete live list of nearby active hazards on the map screen canvas 
# (useful because firebase push alerts only handle one-time temporary events

@router.get("/person/{person_id}/incidents")
def get_nearby_incidents_for_person(person_id: int):
    with get_session() as session:
        
        #look up the person's pre-calculated proximity subscription row mapping coordinates
        row = session.query(models.People_Incident).filter(models.People_Incident.id == person_id).first()
        
        #throw standard web error tracking status layers if workspace node id fails lookup check
        if not row:
            raise HTTPException(status_code=404, detail="Person ID workspace index node not found")
            
        #if they have no active incidents nearby, return an empty array gracefully to client
        if not row.incident_ids:
            return {
                "status": "ok", 
                "person_id": person_id, 
                "count": 0,
                "incidents": []
            }
            
        #extract the detailed data records from current_incidents using those matched spatial map IDs
        nearby_incidents = session.query(models.Current_Incident).filter(
            models.Current_Incident.id.in_(row.incident_ids)
        ).all()
        
        #serialize the database rows into a clean, readable JSON dictionary array context
        incidents_list = []
        for inc in nearby_incidents:
            incidents_list.append({
                "id": inc.id,
                "event_type": inc.event_type,
                "status": inc.status,
                "warning_level": inc.warning_level,
                "state": inc.state,
                "latitude": inc.latitude,
                "longitude": inc.longitude,
                "description": inc.description,
                "address": inc.address,
                "last_updated": inc.last_updated.isoformat() if inc.last_updated else None,
                "test_incident": inc.test_incident,
                "validated_by": inc.validated_by
            })
            
        return {
            "status": "ok",
            "person_id": person_id,
            "count": len(incidents_list),
            "incidents": incidents_list
        }

#---------------------------------------------------------------------------------------------------
class TokenChangeRequest(BaseModel):
    id: int
    new_token: str

@router.patch("/person/update-token")
def update_a_users_fcm_token(data: TokenChangeRequest):
    with get_session() as session:
        
        #first check whether the id exists. if it does, update it
        row = session.get(models.People, data.id)
        if row is None:
            return {
                "status": "failure", 
                "message": "id not found in database"
            }

        row.fcm_token = data.new_token
        session.commit()
        return {
            "status": "ok", 
            "message": "fcm token successfully changed"
        }