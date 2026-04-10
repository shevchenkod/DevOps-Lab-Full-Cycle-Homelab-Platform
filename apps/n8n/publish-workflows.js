// n8n v2.x workflow publisher
// Inserts workflow_published_version, updates activeVersionId, and registers webhooks
// Run inside the pod: node /tmp/publish.js

var sqlite3 = require('/usr/local/lib/node_modules/n8n/node_modules/sqlite3');
var db = new sqlite3.Database('/home/node/.n8n/database.sqlite');

// Workflow IDs and their history version IDs (from workflow_history table)
var workflows = [
  {
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567801',
    versionId: '7e618136-8bc7-4fe0-9fd1-5e69c580f817',
    name: 'Alertmanager → Telegram',
    webhooks: [
      { path: 'alertmanager', method: 'POST', node: 'Alertmanager Webhook', webhookId: 'alertmanager' }
    ]
  },
  {
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567802',
    versionId: '8b0145e9-5b65-4e05-a25f-4a6373622ae1',
    name: 'Telegram Bot (Polling)',
    webhooks: []
  },
  {
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567803',
    versionId: 'aed2f92a-96d3-4f21-a672-5dbb123cb8e7',
    name: 'Daily Cluster Report',
    webhooks: []
  },
  {
    id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567804',
    versionId: 'a83a1400-587e-48ff-8878-5ab18777f435',
    name: 'Webhook Cluster Actions',
    webhooks: [
      { path: 'cluster-action', method: 'POST', node: 'Cluster Action Webhook', webhookId: 'cluster-action' }
    ]
  }
];

var now = new Date().toISOString().replace('T', ' ').replace('Z', '');

function runSeries(tasks, done) {
  if (tasks.length === 0) return done();
  var task = tasks.shift();
  task(function() { runSeries(tasks, done); });
}

var tasks = [];

workflows.forEach(function(wf) {
  // 1. Upsert workflow_published_version
  tasks.push(function(next) {
    db.run(
      "INSERT OR REPLACE INTO workflow_published_version (workflowId, publishedVersionId, createdAt, updatedAt) VALUES (?, ?, ?, ?)",
      [wf.id, wf.versionId, now, now],
      function(err) {
        if (err) console.error('published_version ERR for ' + wf.name + ':', err.message);
        else console.log('[OK] workflow_published_version: ' + wf.name);
        next();
      }
    );
  });

  // 2. Update activeVersionId in workflow_entity
  tasks.push(function(next) {
    db.run(
      "UPDATE workflow_entity SET activeVersionId = ?, updatedAt = ? WHERE id = ?",
      [wf.versionId, now, wf.id],
      function(err) {
        if (err) console.error('activeVersionId ERR for ' + wf.name + ':', err.message);
        else console.log('[OK] activeVersionId: ' + wf.name + ' -> ' + wf.versionId);
        next();
      }
    );
  });

  // 3. Register webhooks
  wf.webhooks.forEach(function(wh) {
    tasks.push(function(next) {
      db.run(
        "INSERT OR REPLACE INTO webhook_entity (workflowId, webhookPath, method, node, webhookId, pathLength) VALUES (?, ?, ?, ?, ?, ?)",
        [wf.id, wh.path, wh.method, wh.node, wh.webhookId, (wh.path.split('/').length - 1) || 1],
        function(err) {
          if (err) console.error('webhook ERR for ' + wh.path + ':', err.message);
          else console.log('[OK] webhook: ' + wh.method + ' /' + wh.path + ' -> ' + wf.name);
          next();
        }
      );
    });
  });
});

// Final: verify
tasks.push(function(next) {
  db.all("SELECT we.id, we.name, we.active, we.activeVersionId, wpv.publishedVersionId FROM workflow_entity we LEFT JOIN workflow_published_version wpv ON we.id = wpv.workflowId", [], function(err, rows) {
    console.log('\n=== Final State ===');
    (rows || []).forEach(function(r) {
      var status = r.active ? '✓ active' : '✗ inactive';
      var pub = r.publishedVersionId ? 'published' : 'DRAFT';
      console.log(status + ' [' + pub + '] ' + r.name);
    });
    db.all("SELECT workflowId, webhookPath, method FROM webhook_entity", [], function(e2, rows2) {
      console.log('\n=== Webhooks ===');
      (rows2 || []).forEach(function(r) { console.log(r.method + ' /' + r.webhookPath + ' -> ' + r.workflowId); });
      db.close();
      next();
    });
  });
});

runSeries(tasks, function() {
  console.log('\nDone! Restart n8n to apply changes.');
});
