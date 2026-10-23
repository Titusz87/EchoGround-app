from app.database import get_session
from app import models

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
