express = require 'express'
serveIndex = require 'serve-index'
fs = require 'fs'
bodyParser = require 'body-parser'
dropbox = require './dropbox'
{createCamera} = require './camera'

camera = createCamera
	imageDirectory: process.env.IMAGE_DIRECTORY || '/tmp/resin-cctv/'
	timezone: process.env.TIMEZONE || 'UTC'
	resolution: process.env.RESOLUTION || '1280x720'
	device: process.env.VIDEO_DEVICE || '/dev/video0'

camera.snapshotLoop( process.env.SNAPSHOT_INTERVAL || 10000 )

camera.on 'snapshot', ( snapshot ) ->
	dropbox.upload snapshot.path, ( err ) ->
		if err?
			console.log( 'Error uploading snapshot to dropbox: ' + err )
			return

console.log('Setting up web server...')
app = express()
app.use(bodyParser.json())
app.use('/images/', express.static(camera.getImageDirectory()))
app.use('/images/', serveIndex(camera.getImageDirectory(), icons: true))
app.get '/', (req, res) ->
	res.send( '<html><head><title>Resin CCTV</title></head><body><img src="/camera.mjpeg"></body></html>'  )

app.get '/camera.mjpeg', (req, res) ->
	res.writeHead 200,
		'Content-Type': 'multipart/x-mixed-replace; boundary=myboundary'
		'Cache-Control': 'no-cache'
		'Connection': 'close'
		'Pragma': 'no-cache'
		
	connClosed = false

	send_snapshot = ( snapshot ) ->
		console.log( 'sending snapshot ' + JSON.stringify( snapshot ) )
		fs.readFile snapshot.path, (err, content) ->
			if err
				console.log( 'Error reading snapshot file ' + err )
			else if not connClosed
				res.write("--myboundary\r\n");
				res.write("Content-Type: image/jpeg\r\n");
				res.write("Content-Length: " + content.length + "\r\n");
				res.write("\r\n");
				res.write(content, 'binary');
				res.write("\r\n");

	lastSnapshot = camera.getLastSnapshot()
	if lastSnapshot
		send_snapshot( lastSnapshot )
	camera.on( 'snapshot', send_snapshot )

	res.connection.on 'close', () ->
		connClosed = true
		camera.removeListener( 'snapshot', send_snapshot )

app.get '/dropbox/authorized', (req, res) ->
	dropbox.authorized( ( err ) ->
		res.send( 200, 'OK' )
	)

app.get '/dropbox/authorize', (req, res) ->
	callbackURL = 'http://192.168.10.8:8080/dropbox/authorized';
	dropbox.authorize callbackURL, ( err, url ) ->
		if err?
			console.log( 'Dropbox uploader error: ' + err )
			res.send( 500, 'Dropbox uploader error: ' + err )
		else
			res.redirect( url )

port = process.env.PORT || 8080
app.listen port, ->
	console.log( 'Web server listening on port ' + port + '.' )
