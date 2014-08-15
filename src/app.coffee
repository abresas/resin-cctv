express = require 'express'
serveIndex = require 'serve-index'
{exec} = require 'child_process'
moment = require 'moment'
fs = require 'fs'

IMG_DIR = '/tmp/camera/'

fs.mkdirSync(IMG_DIR)
console.log('Created image storage directory ' + IMG_DIR + '.')

fs.stat( '/dev/video0', (err, stats) ->
	if err
		console.log('Error reading /dev/video0: ' + err)
	else if !stats.isCharacterDevice()
		console.log('Error reading /dev/video0: Is not a character device.' )
	else
		console.log('Recognized camera device: /dev/video0')
)

console.log('Setting up web server...');
app = express()
app.use('/images/', express.static(IMG_DIR))
app.use('/images/', serveIndex(IMG_DIR, icons: true))
app.get('/view', (req, res) ->
	date = moment().format()
	path = IMG_DIR + date + '.jpg'
	imageProc = exec('fswebcam -r 1280x720 ' + path)
	imageProc.stdout.pipe(process.stdout)
	imageProc.on('exit', ->
		res.sendfile(path)
	)
)

port = process.env.PORT || 8080
app.listen(port, ->
	console.log( 'Web server listening on port ' + port + '.' )
)
