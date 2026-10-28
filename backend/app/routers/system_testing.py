from fastapi import APIRouter, Path, HTTPException, Query
from pydantic import BaseModel
from app.services import db_helpers as db
from app.services.create_fake_data import create_fake_people, create_fake_incidents
from app.database import get_session
from app.models import Base
from sqlalchemy.exc import SQLAlchemyError
from app import models
from app.services import poll_dataquoll as dataquoll
import app.services.system_settings as system_settings


#Commented out for local integration validation tests
#from app.services.firebase import verify_app_check

router = APIRouter()


#------------------routes for testing the system----------------------------------

#create people with random locations
@router.post("/system/create-people")
def create_test_people(number_of_people: int = Query(ge=0, le=10000)): #only numbers between 0 and 10000 allowed
    
    ids = create_fake_people(number_of_people)

    return {
        "status": "ok",
        "message": f"Created fake people with ids: {ids}",
    }

#wipe a single table from db 
@router.delete("/system/erase-table")
def wipe_db_table(table_name: str):

    #check the table name is correct 
    #dict of tables
    table_models = {model.__tablename__: model for model in models.Base.registry._class_registry.values() if isinstance(model, type) and hasattr(model, "__tablename__")
}
    if table_name not in table_models:
        raise HTTPException(
            status_code=404,
            detail={
                "status": "failure",
                "message": f"'{table_name}' does not exist in records.",
            },
        )       
    try:
        with get_session() as session:
            table = table_models[table_name]
            error = db.flush_db_table(session, table)
            if error:
                return {
                    "status": "failure",
                    "message": error,
                } 
            session.commit() #this line may error, meaning we need SQLAlchemyError
        return {
            "status": "ok",
            "message": f"Successfully flushed '{table_name}'.",
        }
    except SQLAlchemyError as e:
        return {
            "status": "failure",
            "message": f"Failed to flush '{table_name}': {e}",
        }

#wipe db tables
#this is a dangerous route to leave unprotected but fine for the prototype 
#could do and AppCheck here and an admin check to make sure they can proceed 
@router.delete("/system/erase-all-records")
def wipe_all_db_records():
    with get_session() as session:
        db.flush_all_tables(session)
        session.commit()
    
    return {
        "status": "ok",
        "message": "Flushed all db tables",
    }

#this route lets you poll and update the db 
@router.post("/system/poll")
async def poll_dataquoll(sync_db: bool):
    
    #can't poll while it's polling
    if dataquoll.poll_lock.locked():
        return {
            "status": "failure",
            "message": "Polling is already in progress."
        }
    
    #reset global var and call polling fn 
    system_settings.set("write_to_db", sync_db)
    await dataquoll.poll_all_states()

    message = "updated db" if system_settings.get("write_to_db") else "did not update db"

    return {
        "status": "ok",
        "message": f"Polled Dataquoll and {message}",
    }

@router.post("/system/create-incidents")
async def create_test_incidents(person_id: int = Query(..., ge=0), number_of_incidents: int = Query(..., ge=0),): #values have to be inputted and greater than 0

    ids = create_fake_incidents(person_id, number_of_incidents)
    return {
            "status": "ok",
            "message": f"created incidents: {ids} near person_id '{person_id}'"
        }

