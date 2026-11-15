from fastapi import APIRouter, HTTPException, Query, Depends, Header
from pydantic import BaseModel
from app.services import db_helpers as db
from app.services.create_fake_data import create_fake_people, create_fake_incidents
from app.database import get_session
from app.models import Base
from sqlalchemy.exc import SQLAlchemyError 
from app import models
from app.services import poll_dataquoll as dataquoll
import app.services.system_settings as system_settings
from sqlalchemy import inspect, text
import json
import os 

#------------setup-------------------------------------------------

#this fn is used to protect all of the routes in this script from abuse
def verify_system_api_key(api_key: str = Header(...)):
    system_api_key = os.getenv("SYSTEM_API_KEY")
    #exit early if .env isn't loaded properly
    if not system_api_key:
        raise HTTPException(
            status_code=500,
            detail="System API key is not configured"
        )
    #reject if wrong key is provided
    if api_key != system_api_key:
        raise HTTPException(
            status_code=401,
            detail="Invalid API key"
        )
    return True

#NOTE: all of the 'system' routes in this script have a required API key check. the API key is in .env
router = APIRouter(prefix="/system", dependencies=[Depends(verify_system_api_key)])

#------------------routes for testing the system----------------------------------

#create people with random locations around Australia 
@router.post("/system/create-people")
def create_test_people(number_of_people: int = Query(ge=0, le=10000)): #only numbers between 0 and 10000 allowed
    
    ids = create_fake_people(number_of_people)

    return {
        "status": "ok",
        "message": f"Created fake people with ids: {ids}",
    }

#----------------------------------------------------------------------------

#wipe a single table from db for convenience 
@router.delete("/system/erase-table")
def wipe_db_table(table_name: str):

    #dict of tables
    table_models = {model.__tablename__: model for model in models.Base.registry._class_registry.values() if isinstance(model, type) and hasattr(model, "__tablename__")}
    
    #check the table name is correct 
    if table_name not in table_models:
        raise HTTPException(
            status_code=404,
            detail={
                "status": "failure",
                "message": f"'{table_name}' does not exist in records.",
            },
        )       
    try: #try to flush the table with a db helper 
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
    
    #handle a the case where the db is not able to flush the table  
    except SQLAlchemyError as e:
        return {
            "status": "failure",
            "message": f"Failed to flush '{table_name}': {e}",
        }

#--------------------------------------------------------------------------------

#wipe the content of all db tables, excluding 'system_settings' which needs to always exist for the program to run
#NOTE this is a dangerous route to leave unprotected but fine for the prototype. A lot of 'system' routes could be abused and should not be in a release build, even with API validation  
@router.delete("/system/erase-all-records")
def wipe_all_db_records():
    with get_session() as session:
        db.flush_all_tables(session)
        session.commit()
    
    return {
        "status": "ok",
        "message": "Flushed all db tables",
    }

#---------------------------------------------------------------------------------------------------------

#this route lets you poll, and optionally update the db with the db sync function 
@router.post("/system/poll")
async def poll_dataquoll(sync_db: bool):
    
    #can't poll while it's polling
    if dataquoll.poll_lock.locked():
        raise HTTPException(status_code=409, detail= "Polling is already in progress.")
    
    #reset global var and call polling fn 
    system_settings.set("write_to_db", sync_db)
    await dataquoll.poll_all_states()

    message = "updated db" if system_settings.get("write_to_db") else "did not update db"

    return {
        "status": "ok",
        "message": f"Polled Dataquoll and {message}",
    }

#--------------------------------------------------------------------------------
#create incidents for testing. Incidents are placed randomly around 'people' in the db according the the 'notify_within_radius' system setting
@router.post("/system/create-incidents")
async def create_test_incidents(person_id: int = Query(..., ge=0), number_of_incidents: int = Query(..., ge=0),): #values have to be inputted and greater than 0

    ids = create_fake_incidents(person_id, number_of_incidents)
    return {
            "status": "ok",
            "message": f"created incidents: {ids} near person_id '{person_id}'"
        }

#----------------------------------------------------------
#print a table (on the backend, it doesn't return the data to the front end) to visualise data in the db
class PrintTableRequest(BaseModel):
    table_name: str

@router.post("/system/print-table")
def print_database_table(data: PrintTableRequest):
    with get_session() as session:

        #try to find the table
        inspector = inspect(session.get_bind())
        table_names = inspector.get_table_names()
        if data.table_name not in table_names:
            raise HTTPException(status_code=404, detail="Table not found")

        #retrieve all rows from the requested table using raw SQL
        quoted_table = inspector.dialect.identifier_preparer.quote(data.table_name)
        rows = session.execute(text(f"SELECT * FROM {quoted_table}")).mappings().all()

        #convert to json and print
        results = [dict(row) for row in rows]
        print(f"{data.table_name}:")
        print(json.dumps(results, indent=4, default=str))

        return {
            "status": "ok",
            "message": f"Printed {len(results)} rows from {data.table_name}",
            "row_count": len(results)
        }