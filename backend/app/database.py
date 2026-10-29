import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from app import models

DATABASE_URL = None
engine = None
SessionLocal = None


# create url that the app will use to connect to the db, then create the engine
def connect_to_db():
    # CHANGED: also declare engine and SessionLocal as globals.
    # WHY: they are assigned at the end of this function. Without 'global' they would
    # only be local variables and get_session() would still see None.
    global DATABASE_URL, engine, SessionLocal

    # CHANGED: use a full DATABASE_URL when it is set (Neon / FastAPI Cloud).
    # WHY: the old code always connected to localhost, which doesn't exist in the cloud.
    url = os.getenv("DATABASE_URL")
    if url:
        # Neon gives "postgresql://...", but the psycopg 3 driver needs "postgresql+psycopg://..."
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql+psycopg://", 1)
        elif url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+psycopg://", 1)
        DATABASE_URL = url
    else:
        # Local fallback: same as before, builds the URL from .env values
        DB_USER = os.getenv('DB_USER')
        DB_PASSWORD = os.getenv('DB_PASSWORD')
        DB_NAME = os.getenv('DB_NAME')

        if not (DB_USER and DB_PASSWORD and DB_NAME):
            raise RuntimeError("Set DATABASE_URL, or DB_USER, DB_PASSWORD and DB_NAME in .env")

        DATABASE_URL = (
            f"postgresql+psycopg://"
            f"{DB_USER}:{DB_PASSWORD}"
            f"@localhost:5432/{DB_NAME}"
        )

    # CHANGED: create the engine, session factory and tables here (this was missing).
    # WHY: nothing created them, so get_session() raised "Engine not created before session started".
    # pool_pre_ping reconnects if Neon's free database was asleep and dropped the connection.
    # create_all creates any missing tables, which a new empty database needs.
    engine = create_engine(DATABASE_URL, pool_pre_ping=True)
    SessionLocal = sessionmaker(bind=engine)
    models.Base.metadata.create_all(engine)


# this is called by table classes when they do db fn's
def get_session():
    if not engine:
        raise RuntimeError("Engine not created before session started")
    return SessionLocal()


def get_db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

def recreate_all_tables():
    models.Base.metadata.create_all(bind=engine)
    print("Recreated all tables")

#delete the actual tables
#delete all tables except system_settings
def delete_all_tables():
    try:
        with get_session() as session:
            bind = session.get_bind()

            #exclude the system settings table
            tables_to_drop = [table for table in models.Base.metadata.sorted_tables if table.name != models.SystemSettings.__tablename__]
            models.Base.metadata.drop_all(bind=bind, tables=tables_to_drop)
            print("Deleted all tables except system_settings")

    except Exception as e:
        print(f"Failed to delete tables: {e}")