from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from datetime import datetime, timezone 
from sqlalchemy import DateTime
from sqlalchemy import Integer, ForeignKey, String, Boolean, Text
from sqlalchemy.dialects.postgresql import ARRAY

#--------------table classes (define how to read and write objects to db)------------------------------

#DeclarativeBase is an sqlalchemy class the we inherit from to create our table classes 
class Base(DeclarativeBase):
    pass

#---------------incident classes------------------------------------------------

#stores the info of current incidents 
class Incident(Base):
    __abstract__ = True #this class to be inherited 

    id: Mapped[str] = mapped_column(primary_key=True)
    event_type: Mapped[str]
    status: Mapped[str]
    warning_level: Mapped[str]
    state: Mapped[str | None]
    latitude: Mapped[float]
    longitude: Mapped[float]
    last_updated: Mapped[datetime | None] #dataquoll provides timezone-aware ISO 8601 timestamps for time values
    reported_time: Mapped[datetime | None] #these values may be blank
    expires: Mapped[datetime | None]       #datetime values might need to be converted to timezone values
    description: Mapped[str | None]
    address: Mapped[str | None]
    created: Mapped[datetime] #this value is created by our program in case 'expires' is null  
    test_incident: Mapped[bool] = mapped_column(Boolean, default=False) #this is a value we can use to track whether we've purposely created a fake incident for testing 
    validated_by: Mapped[list[str]] = mapped_column(ARRAY(String),default=list) #incidents have a list of community names that they are validated by

#these 3 tables inherit from the incident class
#Current_Incident stores the incidents that are in progress
class Current_Incident(Incident):
    __tablename__ = "current_incidents"
#keep incidents that are no longer active for our records
class Archived_Incident(Incident):
    __tablename__ = "archived_incidents"
#this one is handy
class Temporary_Incident(Incident):
    __tablename__ = "temporary_incidents"

#-------------identifier classes--------------------------------------------------------

#people can be households, community leaders or both. fcm token is for pushing notifications to devices
#this is a simple setup where people to devices is one-to-one
class People(Base):
    __tablename__ = "people"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    fcm_token: Mapped[str | None] = mapped_column(String, unique=True, nullable=True) #can be null because the user might not allow notifications immediately  
    latitude: Mapped[float] 
    longitude: Mapped[float]  

#stores info of community leaders  
class Community_Leader(Base):
    __tablename__ = "community_leaders"
    id: Mapped[int] = mapped_column(ForeignKey("people.id"), primary_key=True) #a person can also be a household and/or a community leader
    first_name: Mapped[str]
    phone: Mapped[str]
    password: Mapped[str | None] = mapped_column(String)
    community_name: Mapped[str] = mapped_column(String, nullable=False) 
    community_members: Mapped[list[int]] = mapped_column(ARRAY(Integer),default=list)

#stores info of individual households (users)
class Household(Base):
    __tablename__ = "households"
    id: Mapped[int] = mapped_column(ForeignKey("people.id"), primary_key=True)
    last_name: Mapped[str]
    phone: Mapped[str]
    count: Mapped[int | None] = mapped_column(Integer, default=None)
    password: Mapped[str | None] = mapped_column(String)

    #this value is assigned for convenience when a household is registered to a community
    community_leader_id: Mapped[int | None] = mapped_column(ForeignKey("community_leaders.id"), default=None)


#------------------profile classes------------------------------------------------------------

#this table store the community info that is created by community leaders
#NOTE this model is probably not needed, as the community leader will have 1 community, and store member ids in a list
# class Community_Profile(Base):
#     __tablename__ = "community_profiles"
#     id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

#we need to remember which incidents affect which people
class People_Incident(Base):
    __tablename__ = "people_incidents"
    id: Mapped[int] = mapped_column(ForeignKey("people.id"),primary_key=True)           #this is the same as the primary key for people
    incident_ids: Mapped[list[str]] = mapped_column(ARRAY(String),default=list)         #this string can store the id's of incidents

#this table stores all the emergency reports that are sent to community leaders
class Emergency_Report(Base):
    __tablename__ = "emergency_reports"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sender_id: Mapped[int] = mapped_column(ForeignKey("people.id"), nullable=False)                       #the id of the person who submitted the report
    community_leader_id:  Mapped[int] = mapped_column(ForeignKey("community_leaders.id"), nullable=False) #this is the community leader id taken from 
    title: Mapped[str] = mapped_column(String, nullable=False)
    location: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False) #use text field because it can be longer 
    created: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False) #we don't need to ask for this value

#--------------------system settings/info-----------------------------------------------------

#using this instead of global vars for the programs behavior 
class SystemSettings(Base):
    __tablename__ = "system_settings"
    key: Mapped[str] = mapped_column(String, primary_key=True)

    #db functionality
    write_to_db: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    delete_all_tables: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    fcm_token_verification: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False) #track whether users need their fcm token to be correct when doing stuff like logging in

    #controls polling behavior
    auto_poll: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    poll_on_startup: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    auto_poll_interval: Mapped[int] = mapped_column(Integer, default=15, nullable=False)

    #run a firebase test on startup
    test_firebase_notification_system: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    #variables for incident sync
    stale_incident_time_days: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    push_user_notifications: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    fake_incident_id_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    notify_within_radius: Mapped[int] = mapped_column(Integer, default=20, nullable=False)

    #count stuff inside the program
    test_incident_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False) #use this to create fake incident ids