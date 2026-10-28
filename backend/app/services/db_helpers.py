from sqlalchemy import select, inspect, delete
from app.database import get_session
from app.database import engine
from app.models import Base
from app import models

#-------config-------------------------------------

verbose_debug = False


#----------helpers-------------------------------------
#convert incidents between our python class and table class after polling
def convert_incidents_orm_objects(incidents, incident_type):
    translated = []
    for incident in incidents:
        current_incident = incident_type(
            id = incident.id,
            event_type = incident.event_type,
            status = incident.status, 
            warning_level = incident.warning_level, 
            state = incident.state,
            latitude = incident.latitude, 
            longitude = incident.longitude, 
            reported_time = incident.reported_time,
            last_updated = incident.last_updated,
            expires = incident.expires,
            description = incident.description, 
            address = incident.address,
            created = incident.created,
            test_incident = incident.test_incident,
            validated_by = incident.validated_by
        )
        translated.append(current_incident)
    return translated

#postgresql can insert any mixed list of table objects into db easily
def write_list_to_db(session, objects):
    try:
        session.add_all(objects)  
        if verbose_debug:
            print(f"Added {len(objects)} objects to db session")
    except Exception as e:
        print(f"Failed to write objects to db: {e}")

#delete row by inputting a table_object list 
def delete_db_rows(session, rows):
    try:
        for row in rows:
            session.delete(row)

        if verbose_debug:
            print(f"Prepared {len(rows)} rows to be deleted")
    except Exception as e:
        print(f"Failed to delete rows from db: {e}")

#reading is the opposite process 
def get_all_rows(session, model):
    try:
        result = session.execute(select(model))
        return result.scalars().all()                     #scalars turns row into objects. Returned objects are detached when session closes 
    except Exception as e:
        print(f"Failed to get table from db: {e}")

#get rows by filtering a table by it's fields 
#input a dictionary like {field: value}
def get_db_rows_by_all_fields(session, model, fields):
    query = select(model)

    for field, value in fields.items():
        query = query.where(getattr(model, field) == value) #every time it runs the list gets narrowed down
    rows = session.execute(query).scalars().all()

    if verbose_debug:
        print(
            f"Selected {len(rows)} rows from "
            f"{model.__tablename__} table where {fields}"
        )
    return rows

#return all the id's from a table
def get_ids_from_table(session, model):
    try:
        result = session.execute(select(model.id)) #id is always the primary key in our tables
        return result.scalars().all()
    except Exception as e:
        print(f"Failed to get ids from table {model.__tablename__}: {e}")

#sort of the opposite of 'get_ids'
def get_rows_from_ids(session, model, ids):
    try:
        result = session.execute(select(model).where(model.id.in_(ids))) 
        return result.scalars().all()
    except Exception as e:
        print(f"Failed to get the rows from table {model.__tablename__} by their ids: {e}")

#wipe all the rows from a table
def flush_db_table(session, model):
    try:
        session.execute(delete(model))

        print(f"Prepared all rows from {model.__tablename__} to be deleted")
    except Exception as e:
        message = f"Failed to flush db table: {e}"
        print(message)
        return message

def flush_all_tables(session):
    try:
        for table in reversed(Base.metadata.sorted_tables):
            #don't erase the system settings!!!
            if table.name == "system_settings":
                continue
            session.execute(table.delete())
        print("Wiped all data from all tables")
    except Exception as e:
        print(f"Failed to wipe data from all tables: {e}")

#delete the actual tables
# Delete all tables except system_settings
def delete_all_tables():
    try:
        with get_session() as session:
            bind = session.get_bind()

            #exclude the system settings table
            tables_to_drop = [table for table in Base.metadata.sorted_tables if table.name != models.SystemSettings.__tablename__]
            Base.metadata.drop_all(bind=bind, tables=tables_to_drop)
            print("Deleted all tables except system_settings")

    except Exception as e:
        print(f"Failed to delete tables: {e}")

#return any wanted info about tables for debugging
def print_table_info(session, model):
    try:
        current_incidents = get_all_rows(session, model)
        print(f"Size of {model.__tablename__} table: {len(current_incidents)}")
    except Exception as e:
        print(f"Failed to get table info: {e}")    

#retrieve a column value from a specific row
def get_value_by_id(session, model, row_id, column):
    row = session.get(model, row_id)
    if row is None:
        print(f"Could not retrieve value in {column} by id from {model.__tablename__}")
        return None
    return getattr(row, column)

#retrieve all values of a column from a table
def get_column(session, model, field):
    if not hasattr(model, field):
        print("Incorrect column name inputted in source code")
        return []
    column = getattr(model, field)
    return session.execute(select(column)).scalars().all()