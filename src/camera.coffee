fs = require 'fs'
moment = require 'moment-timezone'
{exec} = require 'child_process'
{EventEmitter} = require 'events'

createCamera = ( _opts ) ->
	camera = new EventEmitter

	opts =
		imageDirectory: _opts.imageDirectory || '/tmp/resin-cctv/'
		timezone: _opts.timezone || 'UTC'
		resolution: _opts.resolution || '1280x720'
		device: _opts.device || '/dev/video0'
	
	if opts.imageDirectory[ opts.imageDirectory.length - 1 ] isnt '/'
		opts.imageDirectory += '/'

	lastSnapshot = null

	camera.getLastSnapshot = () ->
		return lastSnapshot
	
	camera.getImageDirectory = () ->
		return opts.imageDirectory

	camera.setup = () ->
		try
			fs.mkdirSync(opts.imageDirectory)
			console.log('Created image storage directory ' + opts.imageDirectory + '.')
		catch error
			console.log('Error creating image storage directory ' + opts.imageDirectory + ': ' + error )

		fs.stat( opts.device, (err, stats) ->
			if err
				console.log('Error reading ' + opts.device + ': ' + err)
			else if !stats.isCharacterDevice()
				console.log('Error reading ' + opts.device + ': Is not a character device.' )
			else
				console.log('Recognized camera device: ' + opts.device)
		)

	camera.takeSnapshot = ->
		mom = moment().tz( opts.timezone )
		date = mom.format()
		path = opts.imageDirectory + date + '.jpg'
		imageProc = exec 'fswebcam -r ' + opts.resolution + ' --timestamp "' + date + '" --title "Resin CCTV" --font /usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf ' + path, (error, stdout, stderr) ->
			if error?
				console.log( 'Error taking snapshot: ' + error )
				return
			console.log( 'fswebcam ' + JSON.stringify( stdout ) + ' ' + JSON.stringify( stderr ) );
			lastSnapshot =
				path: path
				date: date
				moment: mom
				url: '/images/' + date + '.jpg'
			camera.emit( 'snapshot', lastSnapshot )
		imageProc.stdout.pipe(process.stdout)

	camera.snapshotLoop = (interval) ->
		camera.takeSnapshot() # call once for now, setInterval will call first time in 5s
		setInterval( camera.takeSnapshot, interval )

	camera.setup()
	return camera

exports.createCamera = createCamera
