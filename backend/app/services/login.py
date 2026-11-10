from app.services import db_helpers as db
from app.database import get_session
from app import models
from app.services import system_settings

#check for person_id and fcm token pair to validate person exists in db 
def verify_person_creds(person_id, fcm_token = None):
    with get_session() as session:

        person = session.get(models.People, person_id)
        if person is None:
            return "person_id not found in database"

        #we only need to check the token if the system setting is set
        required_fcm_token_verification = system_settings.get("fcm_token_verification")
        if not required_fcm_token_verification:
            return True

        #now check if the person has a token and if the person-token pair is valid
        if person.fcm_token is None:
            return "fcm token was not registered to person_id" 
        if person.fcm_token != fcm_token:
            return "person_id and fcm_token pair do not match" 

        return True

def normalise_phone(phone):
    """Match existing display formats, including Australian +61 and local 0."""
    import re
    digits = re.sub(r"[^0-9]", "", str(phone or ""))
    if len(digits) == 13 and digits.startswith("0061"):
        return "0" + digits[4:]
    if len(digits) == 11 and digits.startswith("61"):
        return "0" + digits[2:]
    return digits


def login(id, password, model, phone=None, fcm_token=None):
    with get_session() as session:
        if phone is not None:
            number = normalise_phone(phone)
            if not number:
                return False
            # Existing phones are stored with varying formatting. This prototype
            # normalises on lookup without altering saved data or the schema.
            matches = [row for row in session.query(model).all()
                       if normalise_phone(row.phone) == number]
            # Never guess which account to use if old data contains duplicates.
            if len(matches) != 1:
                return False
            row = matches[0]
        else:
            row = session.get(model, id) if id is not None else None
        if row is None or row.password != password:
            return False

        # Preserve the backend's current password-verification scheme. The
        # separate security branch must retain its own hash verifier instead.
        if fcm_token and fcm_token.strip():
            token = fcm_token.strip()
            target = session.get(models.People, row.id)
            if target is None:
                return False
            previous = session.query(models.People).filter(models.People.fcm_token == token).first()
            if previous is not None and previous.id != target.id:
                previous.fcm_token = None
                session.flush()  # release the unique token before assigning it
            target.fcm_token = token
            session.commit()
            session.refresh(row)  # load attributes before leaving the session
        return row
