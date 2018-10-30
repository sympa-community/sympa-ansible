from ansible.plugins.action import ActionBase
import jinja2


class ActionModule(ActionBase):

    def run(self, tmp=None, task_vars=None):
        result = super(ActionModule, self).run(tmp, task_vars)
        return dict(version_value=jinja2.__version__)
