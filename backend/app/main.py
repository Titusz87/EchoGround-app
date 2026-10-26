import sys
import os
# Inject path setter to guarantee relative cloud container module paths resolve cleanly
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from contextlib import asynccontextmanager
from fastapi import FastAPI, Response
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from app.services.betterstack_log import setup_betterstack
from app.services.poll_dataquoll import poll_all_states, setup_polling
from app.services.incident_sync import custom_quadtree
from app.services.firebase import initialise_firebase, firebase_test_notification
from app.database import connect_to_db, get_session
from app.routers.registration import router as registration_router
from app.routers.system_testing import router as system_testing_router
#from app.routers.something_else import router as something_else
from app.services import db_helpers as db
from app import models
from app.services.create_fake_data import create_fake_people
from app.services import system_settings as system_settings

#--------------Better Stack logging---------------------------------  

setup_betterstack()                                                   

#-----------------------------------------------------

#this code runs when the server is created 
#'asynccontextmanager' decorator makes 'lifespan' fn work as a context manager  
@asynccontextmanager
async def lifespan(app: FastAPI):
    #one time setup stuff runs here 
    load_dotenv(".env")
    firebase_app = initialise_firebase()
    app.state.firebase_app = firebase_app
    connect_to_db()
    system_settings.initialise_system_settings() #this can only be called after connecting to the db 
    setup_polling()
    do_additional_db_jobs()
    do_additional_firebase_jobs()
    if system_settings.get("poll_on_startup"):
        await poll_all_states() #poll immediately on startup for testing
    
    #schedule polling (and database sync/ push notifications)
    scheduler = AsyncIOScheduler()
    if system_settings.get("auto_poll"):
        scheduler.add_job(poll_all_states, "interval", minutes=system_settings.get("auto_poll_interval"))
    scheduler.start()
    yield
    scheduler.shutdown()

# Initialize FastAPI with explicit global CORS configurations directly
app = FastAPI(
    lifespan=lifespan,
    openapi_url="/openapi.json",
    docs_url="/docs"
)

# Explicitly bind middleware directly onto the app container instance
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://titusz87.github.io", "http://localhost"], # Trust GitHub Pages production domain and local workspace
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS", "PUT", "DELETE"], # Explicitly declare permitted preflight methods
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=600, # Cache preflight responses for 10 minutes to reduce network overhead
)

# ---- GLOBAL PREFLIGHT INTERCEPTOR ----
# Catch browser OPTIONS requests globally before they hit sub-router validation dependencies
@app.options("/{rest_of_path:path}")
async def preflight_handler(request_response: Response):
    return request_response

# Adds sub-routers AFTER the interceptor handler is established
app.include_router(registration_router)
app.include_router(system_testing_router)

#the root of the API
@app.get("/")
def root():
    return {"message": "Hello from EchoGround!"}

#can do database stuff here
def do_additional_db_jobs():
    with get_session() as session:

        #nothing needed here at the moment

        session.commit()

def do_additional_firebase_jobs():
    if system_settings.get("test_firebase_notification_system"):
        firebase_test_notification()

