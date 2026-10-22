from geopy.distance import geodesic
from app.services.registration import create_person
import random

def create_random_people(amount):
    for i in range(amount):
        latitude = random.uniform(-43.6, -10.0)
        longitude = random.uniform(113.0, 153.6)
        create_person(latitude, longitude)
    print(f"Created {i} fake people with random locations in Aus")

def create_random_incidents(amount):
    pass 





