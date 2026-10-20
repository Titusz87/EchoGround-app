from app.models import People, People_Incident
from app.database import get_session

def create_person(_latitude, _longitude, _fcm_token = None):
    with get_session() as session:

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