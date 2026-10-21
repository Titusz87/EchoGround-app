from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.orm import Mapped
from sqlalchemy.orm import mapped_column
from datetime import datetime 
from sqlalchemy import DateTime
from sqlalchemy import Integer, ForeignKey, String
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
    state: Mapped[str]
    latitude: Mapped[float]
    longitude: Mapped[float]
    last_updated: Mapped[datetime] #dataquoll provides timezone-aware ISO 8601 timestamps for time values
    reported_time: Mapped[datetime | None] #these values may be blank
    expires: Mapped[datetime | None]       #datetime values might need to be converted to timezone values
    description: Mapped[str | None]
    address: Mapped[str | None]

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
    household_id: Mapped[int | None] = mapped_column(ForeignKey("households.id"), nullable=True)                        
    community_leader_id: Mapped[int | None] = mapped_column(ForeignKey("community_leaders.id"), nullable=True)

#stores info of community leaders  
class Community_Leader(Base):
    __tablename__ = "community_leaders"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True) #auto generate integer ids 
    name: Mapped[str]
    latitude: Mapped[float] 
    longitude: Mapped[float] 

#stores info of individual households (users)
class Household(Base):
    __tablename__ = "households"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str]
    latitude: Mapped[float] 
    longitude: Mapped[float] 

#-------------------------------------------------------------------------------------------------

#this table store the community info that is created by community leaders
class Community_Profile(Base):
    __tablename__ = "community_profiles"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

#we need to remember which incidents affect which people
class People_Incident(Base):
    __tablename__ = "people_incidents"
    id: Mapped[int] = mapped_column(ForeignKey("people.id"),primary_key=True)           #this is the same as the primary key for people
    incident_ids: Mapped[list[str]] = mapped_column(ARRAY(String),default=list)         #this string can store the id's of incidents
