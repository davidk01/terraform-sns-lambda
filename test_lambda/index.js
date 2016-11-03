var https = require('https');

exports.handler = function(event, context, callback) {
  https.get('https://abc/ping/1.1.1.1', function(result) {
    context.succeed('DONE');
  }).on('error', function(error) {
    context.done(null, 'ERROR');
  });
};
