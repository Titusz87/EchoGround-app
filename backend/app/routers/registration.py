from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from app.services.registration import create_person
from app.database import get_session
from app import models
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

#TODO this needs to be safe (if a network failure happens the device can't create 2 people entries)

#-----------------------------------------------------------------------------------------


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
                "last_updated": inc.last_updated.isoformat() if inc.last_updated else None
            })
            
        return {
            "status": "ok",
            "person_id": person_id,
            "count": len(incidents_list),
            "incidents": incidents_list
        }

