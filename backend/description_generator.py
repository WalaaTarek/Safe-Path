def generate_first_sentence(scene):

    parts = []

    if scene["people"] > 0:
        if scene["people"] == 1:
            parts.append("one person")
        else:
            parts.append(f"{scene['people']} people")

    for obj in scene["objects"]:
        label = obj["label"]
        color = obj.get("color", "")
        text = f"{color} {label}" if color else label
        parts.append(text)

    if not parts:
        return "No clear objects are detected ahead."

    return "There is " + ", ".join(parts[:-1]) + \
           (" and " + parts[-1] if len(parts) > 1 else parts[0]) + \
           " in front of you."


def generate_second_sentence(scene):
    if scene["people"] > 3:
        return "The area seems somewhat crowded."
    elif len(scene["objects"]) > 0:
        return "There are some objects ahead."
    else:
        return "The path ahead seems clear."


def generate_description(scene):
    return generate_first_sentence(scene) + " " + generate_second_sentence(scene)