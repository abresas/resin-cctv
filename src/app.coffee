express = require 'express'
serveIndex = require 'serve-index'
{exec} = require 'child_process'
moment = require 'moment-timezone'
fs = require 'fs'
bodyParser = require 'body-parser'
dropbox = require './dropbox'

IMG_DIR = '/tmp/resin-cctv/'
timezone = process.env.TIMEZONE || 'UTC'

try
	fs.mkdirSync(IMG_DIR)
	console.log('Created image storage directory ' + IMG_DIR + '.')
catch error
	console.log('Error creating image storage directory ' + IMG_DIR + ': ' + error )

fs.stat( '/dev/video0', (err, stats) ->
	if err
		console.log('Error reading /dev/video0: ' + err)
	else if !stats.isCharacterDevice()
		console.log('Error reading /dev/video0: Is not a character device.' )
	else
		console.log('Recognized camera device: /dev/video0')
)

lastSnapshot = null

takeSnapshot = ->
	mom = moment().tz( timezone )
	date = mom.format()
	path = IMG_DIR + date + '.jpg'
	imageProc = exec('fswebcam -r 1280x720 ' + path, (error, stdout, stderr) ->
		if error?
			console.log( 'Error taking snapshot: ' + error )
			return
		lastSnapshot =
			path: path
			date: date
			moment: mom
			url: '/images/' + date + '.jpg'
		dropbox.upload( path, '/' + date + '.jpg', ( err ) ->
			if err?
				console.log( 'Error uploading snapshot to dropbox: ' + err )
				return
		)
	)
	imageProc.stdout.pipe(process.stdout)

takeSnapshot() # call once for now, setInterval will call first time in 5s
setInterval( takeSnapshot, 10000 )

console.log('Setting up web server...')
app = express()
app.use(bodyParser.json())
app.use('/images/', express.static(IMG_DIR))
app.use('/images/', serveIndex(IMG_DIR, icons: true))
app.get('/', (req, res) ->
	if lastSnapshot?
		res.send( '<html><head><title>Resin CCTV</title><meta http-equiv="refresh" content="5"></head><body><h1>' + lastSnapshot.moment.format( 'DD-MM-YYYY H:mm:ss' ) + '</h1><img src="' + lastSnapshot.url + '"></body></html>'  )
)
app.get('/dropbox/authorized', (req, res) ->
	dropbox.authorized( ( err ) ->
		res.send( 200, 'OK' )
	)
)
app.get('/dropbox/authorize', (req, res) ->
	callbackURL = 'http://192.168.10.8:8080/dropbox/authorized';
	dropbox.authorize( callbackURL, ( err, url ) ->
		if err?
			console.log( 'Dropbox uploader error: ' + err )
			res.send( 500, 'Dropbox uploader error: ' + err )
		else
			res.redirect( url )
	)
)

port = process.env.PORT || 8080
app.listen(port, ->
	console.log( 'Web server listening on port ' + port + '.' )
)
