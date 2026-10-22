from fastapi import APIRouter, Path
from pydantic import BaseModel
from app.services import db_helpers as db
from app.services.create_fake_data import create_random_people
from app.database import get_session
# Commented out for local integration validation tests
# from app.services.firebase import verify_app_check

router = APIRouter()


#------------------routes for testing the system----------------------------------

#create people with random locations
@router.post("/person/create-people/{number_of_people}")
def create_fake_people(number_of_people: int = Path(ge=0, le=10000)): #only numbers between 0 and 10000 allowed
    
    create_random_people(number_of_people)

    return {
        "status": "ok",
        "message": "Created {number_of_people} fake people",
    }

#wipe db tables
#this is a dangerous route to leave unprotected but fine for the prototype 
#could do and AppCheck here and an admin check to make sure they can proceed 
@router.delete("/system/erase-db-records")
def wipe_db():
    with get_session() as session:
        db.flush_all_tables(session)
        session.commit()
    
    return {
        "status": "ok",
        "message": "Flushed all db tables",
    }




#TODO wipe a single table
#TODO other testing routes 
#TODO poll 

