from fastapi import APIRouter

router = APIRouter()


users = []


@router.post("/signup")
async def signup(data: dict):

    email = data["email"]
    password = data["password"]

    for user in users:
        if user["email"] == email:
            return {
                "message": "Email already exists"
            }

    users.append({
        "email": email,
        "password": password
    })

    return {
        "message": "Account created successfully"
    }



@router.post("/login")
async def login(data: dict):

    email = data["email"]
    password = data["password"]


    for user in users:

        if (
            user["email"] == email
            and user["password"] == password
        ):

            return {
                "message": "Login success"
            }


    return {
        "message": "Invalid email or password"
    }