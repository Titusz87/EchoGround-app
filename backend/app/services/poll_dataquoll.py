import httpx
import os
from dotenv import load_dotenv
from datetime import datetime, timezone
from app.services.incident_sync import update_database_incidents
import asyncio

#-------vars------------------------------------------------

event_types = set()
statuses = set()
warning_levels = set()
unset_values = set()
API_KEY = None 

#--------------config------------------------------------

verbose_debug = False
write_to_db = True
poll_states = ["nsw", "vic", "qld", "wa", "sa", "tas", "act", "nt"]
poll_lock = asyncio.Lock()

#-------classes------------------------------------------------
class Incident:
    def __init__(self, id, properties):
        try:
            self.id = id
            self.event_type = properties["eventType"]
            self.status = properties["status"]
            self.warning_level = properties["warningLevel"]
            self.state = properties["location"]["state"]
            self.latitude = properties["location"]["latitude"]
            self.longitude = properties["location"]["longitude"]
            self.last_updated = datetime.fromisoformat(properties["timestamps"]["updated"]) #we need to create time variables for some fields 
            
            #these fields may not have any data     
            self.description = properties["details"].get("description") #.get() is used for safety
            self.address = properties["location"].get("address")
            self.reported_time = (
                        datetime.fromisoformat(properties["timestamps"]["reported"])  #if there is a value given, save it as a datetime otherwise it's None
                        if properties["timestamps"].get("reported")
                        else None
                    )
            self.expires = (
                        datetime.fromisoformat(properties["details"]["expires"]) 
                        if properties["details"].get("expires")
                        else None
                        )
            self.created = datetime.now(timezone.utc)
        except Exception as e:
            print("Error creating Incident object from polling")

        if verbose_debug:
            print(f"Created Incident {self.id}")
            self.check_values_set()

    #vars is a dict of all object fields 
    def check_values_set(self):
        count = 0
        for attribute, value in vars(self).items():
            if value is None:
                #print(f"\t{attribute} is not set")
                unset_values.add(attribute)


#--------functions----------------------------------------

#this fn runs when the server starts. Sets .env vars
def setup_polling():
    #get API key from env file 
    global API_KEY
    API_KEY = os.getenv("Authorization")
    
    #check the key is set properly 
    if not API_KEY:
        raise RuntimeError("Dataquoll api key is not set")
    print("Successfully set Dataquoll api key")

#this fn is called from main.py
async def poll_all_states():
    #make sure this code can't run more than once while requests are arriving in
    async with poll_lock: 
        
        incidents = []
        print("Polling...")
        for s in poll_states:
            if verbose_debug:
                print(f"Polling state: {s}")
            
            state_incidents = await poll_dataquoll_by_state(s)
            
            if verbose_debug:
                print(f"\tRecorded {len(state_incidents)} incidents")
            
            for i in state_incidents:
                incidents.append(i)
        print(f"Polled {len(incidents)} incidents from states: {poll_states}")

        #get more info about dataquoll data if we want 
        print_attribute_sets(incidents)

        #done now, so write new polled data to db if we want
        if write_to_db:
            update_database_incidents(incidents)

    
#get state data from dataquoll api
async def poll_dataquoll_by_state(state):
    #construct the command "curl "https://dataquoll.io/api/v1/incidents" -H "Authorization: Bearer YOUR_API_KEY"
    url = "https://dataquoll.io/api/v1/incidents"
    #the -H flag for html headers
    headers = {
        "Authorization": f"Bearer {API_KEY}"
    }
    #can set other params like this. Best to poll each individual state rather than everywhere at once because the 'limit' may not work 
    params = {
        "state": state,
        "format": "json",
        #500 is max
        "limit": 500       #need to do a check while creating incident objects to ensure that the limit doesn't equal the number of incidents (suggesting that there are more incidents that haven't been scraped)
    }
    
    #await the response from dataquoll as json 
    async with httpx.AsyncClient() as client:
        response = await client.get(url, headers=headers, params=params)
        response.raise_for_status()
        
        data = response.json()    #this is a python dictionary  
        state_incidents = create_incident_objects(data) #sort out our json objects
    return state_incidents

def create_incident_objects(data):
    features = data["features"]
    incident_objects = []
    for feature in features:
        #grab these 2 json chunks and create incident object
        id = feature["id"]
        properties = feature["properties"]
        incident = Incident(id, properties)

        #add to all polled incidents and state specific dictionary
        incident_objects.append(incident)
    return incident_objects
        
def print_attribute_sets(incidents):
    for i in incidents:
        event_types.add(i.event_type)
        statuses.add(i.status)
        warning_levels.add(i.warning_level)

    print("Collected values such as:")
    print(f"\tEvent Types: {event_types}")
    print(f"\tStatuses: {statuses}")
    print(f"\tWarning Levels: {warning_levels}")
    #print(f"\tUnset Values: {unset_values}")



        


    
    
    
   


