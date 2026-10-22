from app.models import People, People_Incident
from app.database import get_session

def create_person(_latitude, _longitude, _fcm_token = None):
    with get_session() as session:

        # ADDED: check if this device token has already been registered in the database before creating a duplicate
        if _fcm_token:
            existing_person = session.query(People).filter(People.fcm_token == _fcm_token).first()
            if existing_person:
                existing_person.latitude = _latitude
                existing_person.longitude = _longitude
                session.commit()
                return existing_person.id

        #create new person (generic id for receiving emergency updates)
        #remember id is auto generated as according to logic in 'models'
        #fcm token might be none. In which case the person won't receive updates 
        person = People(
            latitude = _latitude, 
            longitude = _longitude, 
            fcm_token = _fcm_token,
            household_id = None,                        
            community_leader_id = None
        )
        session.add(person)
        session.flush()                         #ensure the value is in the table before we use it again
        
        #now also create an entry in people_incidents to track incidents a person is 'subscribed' to
        people_incident = People_Incident(id = person.id, incident_ids=[])
        session.add(people_incident)
        
        session.commit()
        return person.id

#create row in household table
def create_household():
    #TODO
    #generate an id. receive data from client
    pass
