const Handlebars = require('handlebars');
const Path = require('path');
const Hapi = require('hapi');
const Hoek = require('hoek');
const azure = require('azure-storage');
const storage = require('./utility/storage');
const tableService = azure.createTableService(process.env.AZURE_STORAGE_ACCOUNT, process.env.AZURE_STORAGE_ACCOUNT_KEY);

const server = new Hapi.Server();
server.connection({ port: process.env.PORT || 3000, host: 'localhost' })

server.register(require('inert'), (err) => {
  server.route({
    method: 'GET',
    path: '/css/{param*}',
    handler: {
        directory: {
            path: 'public/css'
        }
    }
  });

  server.route({
    method: 'GET',
    path: '/fonts/{param*}',
    handler: {
        directory: {
            path: 'public/fonts'
        }
    }
  });
});

Handlebars.registerHelper('ifTrue', text => text === 'True' ? "background-color: #66ff66;" : text === 'Error' ? "background-color: #ff3737;" : "background-color: inherit;");

server.register(require('vision'), (err) => {

  Hoek.assert(!err, err);

  server.views({
    engines: {
        html: Handlebars
    },
    relativeTo: __dirname,
      path: './templates',
    layoutPath: './templates/layout'
  });

  server.route({
    method: 'GET',
    path: '/',
    handler: function (request, reply) {
      const numRows = request.query.rows ? request.query.rows : 100;
      const columns = process.env.TABLE_COLUMNS.split(',').map(c => c.trim());
      const sort = request.query.sort && columns.includes(request.query.sort) ? request.query.sort : 'Timestamp';

      storage.getLastNRows(azure, tableService, columns, numRows, sort, function(error, rows) {
        if (error) {
          console.log(error);
          return reply(error);
        }

        const viewData = {
          rows: rows,
          storageName: process.env.AZURE_STORAGE_ACCOUNT,
          tableName: process.env.TABLE_NAME
        };

        reply.view('index', viewData, { layout: 'main'});
      });
    }
  });
});

server.start((err) => {
  if (err) { throw err; }
  console.log(`Server running at: ${server.info.uri}`);
});
