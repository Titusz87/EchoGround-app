from app.services import db_helpers as db
from app.database import get_session
from app import models
from app.services import system_settings

#check for person_id and fcm token pair to validate person exists in db 
def verify_person_creds(person_id, fcm_token = None):
    with get_session() as session:

        person = session.get(models.People, person_id)
        if person is None:
            return "person_id not found in database"

        #we only need to check the token if the system setting is set
        required_fcm_token_verification = system_settings.get("fcm_token_verification")
        if not required_fcm_token_verification:
            return True

        #now check if the person has a token and if the person-token pair is valid
        if person.fcm_token is None:
            return "fcm token was not registered to person_id" 
        if person.fcm_token != fcm_token:
            return "person_id and fcm_token pair do not match" 

        return True

#this fn should work for both households and community leaders
def login(id, password, model):
    with get_session() as session:

        #get the row and see if the password matches 
        row = session.get(model, id)
        if row is None:
            return False

        #if the pair didn't match login doesn't work
        if row.password != password:
            return False

        return row 

        
        
        