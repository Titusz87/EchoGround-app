from geopy.distance import geodesic
from app.services.registration import create_person
import app.services.db_helpers as db
import random
import math
from app.database import get_session
from app import models
from app.services import system_settings 

def create_fake_people(amount):
    for i in range(amount):
        latitude = random.uniform(-43.6, -10.0)
        longitude = random.uniform(113.0, 153.6)
        create_person(latitude, longitude)
    print(f"Created {i+1} fake people with random locations in Aus")

#TODO: make fake incident and insert into db 
def create_fake_incident():
    pass

def create_fake_incidents(person_id, amount):
    with get_session() as session:
        
        #check if person exists in db and retrieve their lat/lon
        person = session.get(models.People, person_id)
        if person is None:
            return "person id does not exist in db"
        if person.latitude is None or person.longitude is None:
            return "latitude/longitude of person is not set"

        radius = system_settings.get("notify_within_radius")
        latitude, longitude = random_location_within_radius(person.latitude, person.longitude, radius)
        for _ in range(amount):
            create_fake_incident()
    

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
 





