import json
import os
import firebase_admin
from firebase_admin import credentials, messaging, app_check
from fastapi import Header, HTTPException
from firebase_admin.exceptions import FirebaseError
import jwt


# only initialise firebase once for push notifications
def initialise_firebase():

    if firebase_admin._apps:
        print("Firebase is already initialised")
        return firebase_admin.get_app()

    credentials_value = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    if not credentials_value:
        raise RuntimeError(
            "GOOGLE_APPLICATION_CREDENTIALS is not set"
        )

    # CHANGED: accept JSON contents as well as a file path.
    # WHY: the key file isn't in git, so it doesn't exist in FastAPI Cloud.
    credentials_value = credentials_value.strip()

    if credentials_value.startswith("{"):
        # Cloud: the variable contains the JSON itself, so parse it into a dict
        try:
            cred = credentials.Certificate(json.loads(credentials_value))
        except json.JSONDecodeError as e:
            raise RuntimeError(
                "GOOGLE_APPLICATION_CREDENTIALS looks like JSON but could not be "
                "parsed. Re-paste the full contents of the service account file."
            ) from e
    else:
        # Local: the variable is a path to the JSON file on disk
        cred = credentials.Certificate(credentials_value)

    print("Firebase initialised successfully")
    return firebase_admin.initialize_app(cred)


def firebase_test_notification():
    message = messaging.Message(
        notification=messaging.Notification(
            title="Test Notification",
            body="Firebase is connected to your backend!"
        ),

        token="REPLACE_WITH_REAL_FCM_TOKEN"
    )
    response = messaging.send(message)
    print(f"Test notification sent successfully! Message ID: {response}")


# use try catch when calling this fn in case it fails
def send_firebase_notification(_title, _body, _token, _data):
    message = messaging.Message(
        notification=messaging.Notification(
            title=_title,
            body=_body
        ),
        data=_data,
        token=_token
    )
    response = messaging.send(message)
    return response


# verify firebase app check tokens to be authentic. so the user can't register with a fake fcm token
def verify_app_check(
    token: str | None = Header(
        default=None,
        alias="X-Firebase-AppCheck",
    ),
):
    if not token:
        raise HTTPException(
            status_code=401,
            detail="Missing App Check token",
        )
    try:
        firebase_app = firebase_admin.get_app()
        return app_check.verify_token(token, app=firebase_app)  # retrieve the default app with firebase_admin.get_app()
    except ValueError:
        raise HTTPException(
            status_code=401,
            detail="Invalid App Check token",
        )
    except jwt.exceptions.PyJWKClientError:
        raise HTTPException(
            status_code=503,
            detail="Unable to verify App Check token",
        )
    except FirebaseError:
        raise HTTPException(
            status_code=503,
            detail="Unable to verify App Check token",
        )
