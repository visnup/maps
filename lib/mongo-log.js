require('colors');

var inspect = require('util').inspect;

module.exports = function(mongo) {
  var write = mongo.Connection.prototype.write;

  mongo.Connection.prototype.write = function(db_command, callback) {
    if (!db_command) return;

    if (db_command.constructor === Array)
      for (var i = 0, len = db_command.length; i < len; i++)
        log(db_command[i]);
    else
      log(db_command);

    return write.apply(this, arguments);
  }

  function commandName(command) {
    switch (command.constructor) {
      case mongo.BaseCommand:       return 'base';
      case mongo.DbCommand:         return 'db';
      case mongo.DeleteCommand:     return 'delete';
      case mongo.GetMoreCommand:    return 'get_more';
      case mongo.InsertCommand:     return 'insert';
      case mongo.KillCursorCommand: return 'kill_cursor';
      case mongo.QueryCommand:      return 'query';
      case mongo.UpdateCommand:     return 'update';
      default:                      return command;
    }
  }

  function log(command) {
    var output = { collectionName: command.collectionName };

    ['query', 'documents', 'spec', 'document', 'selector', 'returnFieldSelector', 'numberToSkip', 'numberToReturn'].forEach(function(k) {
      if (command[k]) output[k] = command[k];
    });

    console.log((commandName(command).underline + ": " + inspect(output, null, 8)).grey);
  }
};
