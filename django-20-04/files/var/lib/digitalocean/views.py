from django.http import HttpResponse, HttpRequest

helloWorld = """
<!DOCTYPE html>
<html>
<head>
<title>Your Django Droplet</title>
<style>
    body {
        width: 1000px;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
        background: #AAAAAA;
    }
    div {
      padding: 30px;
      background: #FFFFFF;
      margin: 30px;
      border-radius: 5px;
      border: 1px solid #888888;
    }
    pre {
      padding: 15px;
    }
    code, pre {
      font-size: 16px;
      background: #DDDDDD
    }
</style>
</head>
<body>
  <div>
    <h1>Sammy welcomes you to your Droplet!</h1>
    <img src="/static/sammytheshark.gif" />
    <h2>Things to do with this script</h2>
    <p>This message is coming to you via a simple Django application that's live on your Droplet! This droplet is all set up with Python, Django, and Postgres. It's also using Gunicorn to run the application on system boot and using nginx to proxy traffic to the application over port 80.</p>
    <h2>Get your code on here</h2>
    <ul>
      <li>SSH into your Droplet. <pre><code>ssh root@{IPADDRESS}</code></pre></li>
      <li>Provide the password that was emailed to you. You can also use an SSH key, if you selected that option during Droplet creation, by <a href='https://www.digitalocean.com/docs/droplets/how-to/add-ssh-keys/'>following these instructions</a>.</li>
      <li>Note the login message, it has important details for connecting to your Postgres database, among other things!</li>
      <li><code>git clone</code> your code onto the droplet. You can try to reuse this project, located in <code>/home/django/django_project</code>, or start fresh in a new location and edit Gunicorn's configuration to point to it at <code>/etc/systemd/system/gunicorn.service</code>. You can also change how nginx is routing traffic by editing <code>/etc/nginx/sites-enabled/django</code></li>
      <ul>
        <li>Note: If you're not using a source control, you can <a href="https://www.digitalocean.com/docs/droplets/how-to/transfer-files/">directly upload the files to your droplet using SFTP</a>.
      </ul>
      <li><code>cd</code> into the directory where your Python  code lives, and install any dependencies. For example, if you have a <code>requirements.txt</code> file, run <code>pip install -r requirements.txt</code>.
      <li>That's it! Whenever you make code changes, reload Gunicorn like so: <pre><code>PID=$(systemctl show --value -p MainPID gunicorn.service) && kill -HUP $PID</code></pre></li>
    </ul>
    <h2>Play in the admin area</h2>
    <p>The standard Django admin area is accessible at <a href="/admin">/admin</a>. The login and password are stored in the <code>DJANGO_USER*</code> values you see when you call  <code>cat /root/.digitalocean_passwords</code> while logged in over SSH.</p>
    <h2>Get production-ready</h2>
    <ul>
      <li><a href="https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-18-04">Set up a non-root user for day-to-day use</a></li>
      <li><a href="https://www.digitalocean.com/docs/networking/firewalls/">Set up a DigitalOcean cloud firewall</a> (they're free).</li>
      <li><a href="https://www.digitalocean.com/docs/networking/dns/quickstart/">Register a custom domain</a></li>
      <li>Have data needs? You can mount a <a href="https://www.digitalocean.com/docs/volumes/">volume</a> (up to 16TB)
        to this server to expand the filesyem, provision a <a href="https://www.digitalocean.com/docs/databases/">database cluster</a> (that runs MySQL, Redis, or PostgreSQL),
        or use a <a href="https://www.digitalocean.com/docs/spaces/">Space</a>, which is an S3-compatible bucket for storing objects.
    </ul>
  </div>
</body>
</html>
"""

def index(request):
    return HttpResponse(helloWorld.replace("{IPADDRESS}",request.get_host()))
