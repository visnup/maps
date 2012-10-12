
/**
 * Module dependencies.
 */

var express = require('express')
  , http = require('http')
  , coffee = require('coffee-script')
  , fs = require('fs');

var app = express();

app.configure(function(){
  app.set('port', process.env.PORT || 8003);
  app.set('views', __dirname + '/views');
  app.set('view engine', 'jade');
  app.use(express.favicon());
  app.use(express.logger('dev'));
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(__dirname + '/public'));
});

app.configure('development', function(){
  app.use(express.errorHandler());
});

app.db = require('./models');

app.get('/', index);
app.get('/maps', index);
app.get('/javascripts/application.js', function(req, res, next) {
  var name = __dirname + '/public/javascripts/application.coffee';
  fs.readFile(name, function(err, file) {
    if (err) return next(err);
    res.send(coffee.compile(file.toString()));
  });
});

function index(req, res) {
  res.render('index', { q: req.param('q') });
}

(function() {
  var Favorite = app.db.model('Favorite');

  app.get('/favorites', function(req, res, next) {
    Favorite.find({ checked: true }, function(err, favorites) {
      if (err) return next(err);
      res.send(favorites);
    });
  });

  app.post('/favorites', function(req, res, next) {
    Favorite.create(req.body, function(err, favorite) {
      if (err) return next(err);
      res.send(favorite);
    });
  });

  app.put('/favorites/:id', function(req, res, next) {
    delete req.body._id;

    Favorite.findByIdAndUpdate(req.param('id'), { $set: req.body }, function(err, favorite) {
      if (err) return next(err);
      res.send({});
    });
  });
})();


http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port " + app.get('port'));
});
