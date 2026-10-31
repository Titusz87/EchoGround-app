from app.services.create_records import create_person
import app.services.db_helpers as db
import math
from app.database import get_session
from app import models
from app.services import system_settings 
import random 
from datetime import datetime, timezone
from app.services import incident_sync 

event_types = ['bushfire', 'medical', 'flood', 'earthquake', 'vehicle_accident', 'storm']
warning_levels = ['advice', 'none', 'watch_and_act']

def create_fake_people(amount):
    ids = []
    for i in range(amount):
        latitude = random.uniform(-43.6, -10.0)
        longitude = random.uniform(113.0, 153.6)
        id = create_person(latitude, longitude)
        ids.append(id)
    print(f"Created {i+1} test people with random locations in Aus")
    return ids

def create_fake_incident(_latitude, _longitude):   
    #make some fake incidents with the base ORM class
    incident = models.Temporary_Incident(
        id = get_next_fake_id(),
        event_type = random.choice(event_types),
        status = "active",
        warning_level = random.choice(warning_levels),
        latitude = _latitude,
        longitude = _longitude,
        created = datetime.now(timezone.utc),   
        test_incident = True 
    )
    return incident

def create_fake_incidents(person_id, amount):
    if amount < 1:
        print("Cannot create less than 1 test incident")
        return
    
    with get_session() as session:
        
        #check if person exists in db and retrieve their lat/lon
        person = session.get(models.People, person_id)
        if person is None:
            return "person id does not exist in db"
        if person.latitude is None or person.longitude is None:
            return "latitude/longitude of person is not set"

        #create fake incidents with random locations and append them to list
        radius = system_settings.get("notify_within_radius")
        fake_incidents = []
        for _ in range(amount):
            latitude, longitude = random_location_within_radius(person.latitude, person.longitude, radius)
            incident = create_fake_incident(latitude, longitude)
            fake_incidents.append(incident)

    #now sync the database with the new fake incidents
    incident_sync.update_database_incidents(fake_incidents, fake_incidents=True)
    return [incident.id for incident in fake_incidents]
    
#AI generated math 
def random_location_within_radius(latitude: float, longitude: float, radius_km: float) -> tuple[float, float]:
    earth_radius_km = 6371.0
    #Maximum angular distance in radians
    max_angle = radius_km / earth_radius_km
    
    #Random bearing (direction) and distance, uniformly distributed by area
    bearing = random.uniform(0, 2 * math.pi)
    angle = math.acos(1 - random.random() * (1 - math.cos(max_angle)))
    lat1 = math.radians(latitude)
    lon1 = math.radians(longitude)
    
    #Calculate destination latitude
    lat2 = math.asin(math.sin(lat1) * math.cos(angle)+ math.cos(lat1) * math.sin(angle) * math.cos(bearing))
    #Calculate destination longitude
    lon2 = lon1 + math.atan2(math.sin(bearing) * math.sin(angle) * math.cos(lat1),math.cos(angle) - math.sin(lat1) * math.sin(lat2))
    
    #Convert back to degrees and normalise longitude
    new_latitude = math.degrees(lat2)
    new_longitude = (math.degrees(lon2) + 180) % 360 - 180
    
    return new_latitude, new_longitude
 
#----------------------------helpers-------------------------------------

#get the available number of fake incident. then increase it by 1 for the next use
def get_next_fake_id():
    test_incident_count = system_settings.get("test_incident_count")
    system_settings.set("test_incident_count", test_incident_count + 1)
    return f"test_incident{test_incident_count}"
