from app.database import get_session
from app import models
from app import database as db

#if the system vars aren't set yet then set them to these default states
#only call this fn after connection to db is established 
def initialise_system_settings():
    with get_session() as session:

        #first delete the table because we want to recreate it with default values (dumb)
        models.SystemSettings.__table__.drop(bind=db.engine)
        models.SystemSettings.__table__.create(bind=db.engine)
        
        #create default settings if the row doesn't exist
        # settings = session.get(models.SystemSettings, "main")
        # if settings is None:
        #     session.add(models.SystemSettings(key="main"))
        #     session.commit()
        #     print("Created system settings with default values")
        #     return
        # print("Successfully loaded system settings")
        session.add(models.SystemSettings(key="main"))
        session.commit()
        print("Loaded settings with default values")

#open a session and set a setting
def set(setting_name: str, value):
    with get_session() as session:
        settings = session.get(models.SystemSettings, "main")
        if settings is None:
            raise ValueError("System settings have not been initialised")
        if not hasattr(settings, setting_name):
            raise ValueError(f"Unknown system setting: {setting_name}")
        setattr(settings, setting_name, value)
        session.commit()

#get system settings
def get(setting_name: str):
    with get_session() as session:
        settings = session.get(models.SystemSettings, "main")
        if settings is None:
            raise ValueError("System settings have not been initialised")
        if not hasattr(settings, setting_name):
            raise ValueError(f"Unknown system setting: {setting_name}")
        return getattr(settings, setting_name)
