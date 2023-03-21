from flask import Flask, render_template

app = Flask(__name__,
            static_url_path='',
            static_folder='static',
            template_folder='templates')

@app.route("/")
def hello():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host='0.0.0.0')
