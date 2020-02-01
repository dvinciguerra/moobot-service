
# Moobot Service - A pomodoro API made using Sinatra + Sidekiq

## Steps

Clone the project

1. `heroku login`

2. `heroku create`

3. `git init`

4. `git remote add heroku [heroku_git_url]`

5. `git add .`

6. `git push heroku master`

## Running

1. Start a tomato session

```shellscript
curl -X POST "http://localhost:3000/tomato/start" \
  -d $'{
    "minutes": 25,
    "users": ["@DrEggman", "@Bowser"]
  }'
```

2. Get current sessions

```shellscript
curl -X GET "http://localhost:3000/tomato/sessions"
```

3. Restart current sessions

```shellscript
curl -X PUT "http://localhost:3000/tomato/:session-uuid/restart" \
  -d $'{
    "minutes": 30
  }'
```

4. Go to next enqueued user

```shellscript
curl -X PUT "http://localhost:3000/tomato/:session-uuid/next"
```

4. Stop current session

```shellscript
curl -X PUT "http://localhost:3000/tomato/:session-uuid/stop"
```
