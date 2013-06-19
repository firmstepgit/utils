
conf =
	libs: ['aws-sdk', 'q', 'mime']
	encoding: 'utf8'
	port: 8124
	host: '127.0.0.1'
	verbose: yes
	debug: no


utils = require './utils'
[aws, Q, mime] = utils.requireAll conf.libs

_aws = module.exports = exports = {}

_aws.settings =
	public: yes
	aws_config: "./config/config.aws.json"
	wait_time: 20
	visibility_time: 60
	max_messages: 10
	endpoint: ""
	bucket_name: ""
	queue_name: ""
	max_domains: 100
	consistent_read: true

_aws.setup = (options, config) ->
	settings = utils.extend @settings, options
	unless config then aws.config.loadFromPath @settings.aws_config else aws.config.update config

	s3 = new aws.S3()
	sqs = new aws.SQS()
	sdb = new aws.SimpleDB()

	@client = @client_s3 = s3.client
	@client_sqs = sqs.client
	@client_sdb = sdb.client

_aws.bucketExists = (bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.headBucket {Bucket: bucket}, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.getAcl = (bucket=@settings.bucket_name, key) ->
	task = Q.defer()
	obj = {Bucket: bucket}; fn = "getBucketAcl"
	if key then obj.Key = key; fn = "getObjectAcl"

	@client[fn] obj, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.getBucket = (bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.listObjects {Bucket: bucket}, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.createBucket = (bucket=@settings.bucket_name, allowPublic=@settings.public, options) ->
	task = Q.defer()
	obj = utils.extend {Bucket: bucket}, options
	if allowPublic then obj['ACL'] = 'public-read'

	@client.createBucket obj, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.listBuckets = (thisBucket) ->
	task = Q.defer()
	@client.listBuckets (err, data) ->
		return task.reject err if err
		task.resolve data.Buckets
		console.log bucket.Name, "(#{bucket.CreationDate})" for i, bucket of data.Buckets
	task.promise

_aws.deleteBucket = (bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.deleteBucket {Bucket: bucket}, (err, data) =>
		if err?.statusCode is 409
			return @getBucket(bucket).then(
				(data) => Q.all(@deleteObj content.Key, bucket for content in data.Contents).then(
				 		(data) => @deleteBucket(bucket).then task.resolve, task.reject err 
				 		(err) -> task.reject err
				 	)
			)
		return task.reject err if err
		task.resolve data
	task.promise

_aws.objExists = (key, bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.headObject {Bucket:bucket, Key:key}, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.listObj = (bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.listObjects {Bucket: bucket}, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.putObj = (key, body, options, bucket=@settings.bucket_name, allowPublic=@settings.public) ->
	task = Q.defer()
	obj = utils.extend {Bucket: bucket, Key:key, Body:body}, {ContentType: mime.lookup key}, options
	if allowPublic then obj['ACL'] = 'public-read'

	@client.putObject obj, (err, data) =>
		return task.reject err if err
		task.resolve data
		@log key, bucket if conf.debug
	task.promise

_aws.getObj = (key, bucket=@settings.bucket_name) ->
	task = Q.defer()
	@client.getObject {Bucket: bucket, Key:key}, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.deleteObj = (key, bucket=@settings.bucket_name) ->	
	task = Q.defer()
	k = ''
	fn= switch 
		when typeof key is 'string'
			k = 'Key';'deleteObject'
		when typeof key is 'array'
			k = 'Delete'; 'deleteObjects'

	obj = {Bucket: bucket}
	obj["#{k}"] = key
	@client[fn] obj, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.copyObj = (old_key, new_key, new_bucket=@settings.bucket_name, old_bucket=@settings.bucket_name, options, allowPublic=@settings.public) ->
	task = Q.defer()
	src = encodeURIComponent "#{old_bucket}/#{old_key}"
	
	obj = utils.extend {Bucket:new_bucket, Key:new_key, CopySource:src}, {ContentType: mime.lookup new_key}, options
	if allowPublic then obj['ACL'] = 'public-read'

	@client.copyObject obj, (err, data) ->
		return task.reject err if err
		task.resolve data
	task.promise

_aws.getFolder = (key, level=0, bucket=@settings.bucket_name) ->
	task = Q.defer()
	ret = []
	@listObj(bucket).then(
		(data) ->
			(ret.push y if y.Key.split('/')[level] is key) for x, y of data.Contents
			task.resolve [ret, level]
		(err) -> task.reject err
	)
	task.promise

_aws.listQueues = (params) ->
	task = Q.defer()
	@client_sqs.listQueues params, (err, data) ->
		if err then return task.reject err
		task.resolve data
	task.promise

_aws.queueExists = (name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then task.resolve, task.reject
	task.promise

_aws.createQueue = (name=@settings.queue_name) ->	
	task = Q.defer()
	@client_sqs.createQueue {QueueName: name}, (err, data) ->
		if err then return task.reject err
		task.resolve data
	task.promise

_aws.getQueueUrl = (name=@settings.queue_name) ->
	task = Q.defer()
	@client_sqs.getQueueUrl {QueueName: name}, (err, data) ->
		if err then return task.reject err
		task.resolve data
	task.promise

_aws.deleteQueueByUrl = (url=@settings.queue_url) ->
	task = Q.defer()
	@client_sqs.deleteQueue {QueueUrl: url}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.deleteQueue = (name=@settings.queue_name) ->	
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) -> _aws.deleteQueueByUrl(data.QueueUrl).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise

_aws.deleteMessageByUrl = (handle, url=@settings.queue_url) ->
	task = Q.defer()
	@client_sqs.deleteMessage {QueueUrl: url, ReceiptHandle: handle}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.deleteMessage = (handle, name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) => @deleteMessageByUrl(handle, data.QueueUrl).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise
 
_aws.sendMessageByUrl = (body, url=@settings.queue_url) ->
	task = Q.defer()
	@client_sqs.sendMessage {QueueUrl: url, MessageBody: body}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.sendMessage = (body, name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) => @sendMessageByUrl(body, data.QueueUrl).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise

_aws.getMessageByUrl = (url=@settings.queue_url, wait_time=@settings.wait_time, visibility_time=@settings.visibility_time, max_messages=@settings.max_messages) ->
	task = Q.defer()
	wait_time = 20 if wait_time > 20
	wait_time = 0 if wait_time < 0
	max_messages = 10 if max_messages > 10
	max_messages = 1 if max_messages < 1

	obj = 
	 	QueueUrl: url
	 	WaitTimeSeconds: wait_time
	 	VisibilityTimeout:visibility_time
	 	MaxNumberOfMessages: max_messages

	@client_sqs.receiveMessage obj, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.getMessage = (name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) => @getMessageByUrl(data.QueueUrl).then task.resolve, task.reject		
		(err) -> task.reject err
	)
	task.promise

_aws.getQueueAttrByUrl = (url=@settings.queue_url) ->
	task = Q.defer()
	@client_sqs.getQueueAttributes {QueueUrl: url}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.getQueueAttr = (name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) => @getQueueAttrByUrl(data.QueueUrl).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise

_aws.setQueueAttrByUrl = (attr, url=@settings.queue_url) ->
	task = Q.defer()
	@client_sqs.setQueueAttributes {QueueUrl: url, Attributes: attr}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.setQueueAttr = (attr, name=@settings.queue_name) ->
	task = Q.defer()
	@getQueueUrl(name).then(
		(data) => @setQueueAttrByUrl(attr, data.QueueUrl).then task.resolve, task.reject
		(err) -> task.reject err
	)
	task.promise

_aws.listDomains = (max=@settings.max_domains) ->
	task = Q.defer()
	@client_sdb.listDomains {MaxNumberOfDomains:max}, (err, data) ->
		if err then return task.reject err
		console.log data
		task.resolve data	
	task.promise

_aws.createDomain = (name=@settings.domain_name) ->
	task = Q.defer()
	@client_sdb.createDomain {DomainName:name},  (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.deleteDomain = (name=@settings.domain_name) ->
	task = Q.defer()
	@client_sdb.deleteDomain {DomainName:name}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.domainData = (name=@settings.domain_name) ->
	task = Q.defer()
	@client_sdb.domainMetadata {DomainName:name}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.domainExists = (name=@settings.domain_name) ->
	task = Q.defer()
	@domainData(name).then task.resolve, task.reject
	task.promise

_aws.domainSelect = (item, attr, name=@settings.domain_name) ->
	task = Q.defer()

	obj = {DomainName:name, ItemName:item}	
	obj.AttributeNames = attr if attr

	@client_sdb.getAttributes obj, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.domainInsert = (item, attr, name=@settings.domain_name) ->
	task = Q.defer()
	@client_sdb.putAttributes {DomainName:name, ItemName:item, Attributes:attr}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.domainDelete = (item, name=@settings.domain_name) ->
	task = Q.defer()
	@client_sdb.deleteAttributes {DomainName:name, ItemName:item}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.queryDomain = (query, consistent=@settings.consistent_read) ->
	task = Q.defer()
	@client_sdb.select {SelectExpression:query, ConsistentRead:consistent}, (err, data) ->
		if err then return task.reject err
		task.resolve data	
	task.promise

_aws.log = (key, bucket=@setting.bucket_name) ->
	@listBuckets()
	@getBucket(bucket).then (data) -> console.log data
	if key then @getObj(key, bucket).then (data) -> console.log data.Body.toString(conf.encoding)

