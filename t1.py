<!DOCTYPE html>
<html>
<head>
    <title>OCR App</title>
</head>
<body>

<h2>Upload File</h2>

<form action="/upload" method="post" enctype="multipart/form-data">
    <input type="file" name="file">
    <button type="submit">Upload</button>
</form>

{% if text %}
<h3>Result:</h3>
<pre>{{ text }}</pre>
{% endif %}

</body>
</html> 