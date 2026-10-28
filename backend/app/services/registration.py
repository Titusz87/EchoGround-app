from app import models 
from app.database import get_session
from app.services import db_helpers as db

def create_person(_latitude, _longitude, _fcm_token = None):
    with get_session() as session:

        # ADDED: check if this device token has already been registered in the database before creating a duplicate
        if _fcm_token:
            existing_person = session.query(models.People).filter(models.People.fcm_token == _fcm_token).first()
            if existing_person:
                existing_person.latitude = _latitude
                existing_person.longitude = _longitude
                session.commit()
                return existing_person.id

        #create new person (generic id for receiving emergency updates)
        #remember id is auto generated as according to logic in 'models'
        #fcm token might be none. In which case the person won't receive updates 
        person = models.People(
            latitude = _latitude, 
            longitude = _longitude, 
            fcm_token = _fcm_token,
        )
        session.add(person)
        session.flush()                         #ensure the value is in the table before we use it again
        
        #now also create an entry in people_incidents to track incidents a person is 'subscribed' to
        people_incident = models.People_Incident(id = person.id, incident_ids=[])
        session.add(people_incident)
        
        session.commit()
        return person.id

def create_household(_id, _last_name, _phone, _count, _password):
    with get_session() as session:
        #check whether the person already has a household
        existing_household = session.get(models.Household, _id)

        if existing_household is not None:
            return False
        
        #finally make the household
        household = models.Household(
            id=_id,
            last_name=_last_name,
            phone=_phone,
            count=_count,
            password = _password
        )
        session.add(household)
        session.commit()
        print("Successfully registered household")
        return True

def create_community_leader(_id, _first_name, _phone, _password, _community_name):
    with get_session() as session:
        #check whether the person already is a community leader
        existing_c_l = session.get(models.Community_Leader, _id)

        if existing_c_l is not None:
            return "community leader profile has already been created"

        #now check whether the community name is already in use
        community_names = db.get_column(session, models.Community_Leader, "community_name")
        if _community_name in community_names:
            return f"community name {_community_name} is already in use"
        
        #finally make the community leader
        community_leader = models.Community_Leader(
            id=_id,
            first_name=_first_name,
            phone=_phone,
            password = _password,
            community_name = _community_name
        )
        session.add(community_leader)
        session.commit()
        print("Successfully registered community leader")
        return True
