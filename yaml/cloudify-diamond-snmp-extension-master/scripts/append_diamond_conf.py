from cloudify import ctx
from cloudify.state import ctx_parameters as inputs

ctx.logger.info('Appending snmp config')
src_instance = ctx.source.instance
target_instance = ctx.target.instance
target_node = ctx.target.node

config = src_instance.runtime_properties.get('snmp_collector_config', {})

devices_conf = config.get('devices', {})
devices_conf[target_instance.id] = device_config = {}
device_config['node_instance_id'] = target_instance.id
device_config['node_id'] = target_node.id
if 'host' in inputs:
    device_config['host'] = inputs.host
else:
    device_config['host'] = target_instance.host_ip
device_config['port'] = inputs.port
device_config['community'] = inputs.community
device_config['oids'] = inputs.oids

config['devices'] = devices_conf

src_instance.runtime_properties['snmp_collector_config'] = config

ctx.logger.info('SNMP collector config: {0}'.format(str(config)))
