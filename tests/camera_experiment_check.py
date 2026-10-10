"""Ablation safety and evaluation acceptance cases; no provider calls."""
import json
from pathlib import Path
import tempfile
import unittest

from tools.app_control.camera_trial import score
from tools.app_control.desktop_client import DesktopError
from tools.app_control.desktop_session import DesktopGoalSession
from tools.app_control.experiment_session import ExperimentSession
from tests.desktop_session_check import FixtureClient


class ExperimentChecks(unittest.TestCase):
    def make_session(self, mode):
        folder = tempfile.TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        client = FixtureClient()
        base = DesktopGoalSession(client, Path(folder.name)/'camera', max_steps=1, max_observations=2)
        return client, base, ExperimentSession(base, mode)

    def test_blank_binds_delivered_hash_while_physics_uses_real_frame(self):
        client, base, session = self.make_session('blank')
        delivered = session.observe()
        self.assertNotEqual(delivered.metadata['sha256'], base.frame.metadata['sha256'])
        real_sha = base.frame.metadata['sha256']
        session.decide(delivered.metadata['sha256'], 'The image is gray; stop cautiously.', 'brake', 1)
        session.observe()
        session.stop()
        receipt = next(x for x in client.calls if isinstance(x, tuple) and x[0]=='receipt')
        self.assertEqual(receipt[1][1], real_sha)
        self.assertIn('Experiment control / blank', receipt[1][4])
        events = [json.loads(line) for line in (base.output/'events.jsonl').read_text().splitlines()]
        deliveries = [e['data'] for e in events if e['event']=='delivery']
        self.assertEqual(deliveries[0]['delivered_sha256'], delivered.metadata['sha256'])
        self.assertEqual(deliveries[0]['real_sha256'], real_sha)

    def test_real_hash_is_rejected_for_blank_without_acting(self):
        client, base, session = self.make_session('blank')
        session.observe()
        with self.assertRaises(DesktopError):
            session.decide(base.frame.metadata['sha256'], 'Floor.', 'forward', 1)
        self.assertTrue(client.stopped)
        self.assertFalse(any(isinstance(x, tuple) and x[0]=='action' for x in client.calls))

    def test_frozen_delivers_same_bytes_but_new_physics_context(self):
        _, base, session = self.make_session('frozen')
        before = session.observe()
        session.decide(before.metadata['sha256'], 'A fixed view.', 'forward', 3)
        after = session.observe()
        self.assertEqual(before.png, after.png)
        self.assertNotEqual(before.metadata['frame_id'], after.metadata['frame_id'])
        session.stop()
        with self.assertRaises(DesktopError):
            session.observe()

    def test_contact_or_stationary_actor_cannot_pass(self):
        evaluation = {'valid':True, 'travel_x':.1, 'final':{'gap_x':.08}, 'wall_contact':False,
                      'minimum_gap_x':.08, 'rest_ticks':12, 'stopped_state':'stopped'}
        actor = {'final_reobserved':True,'stop_confirmed':True}
        criteria = {'minimum_travel':.03,'minimum_gap':.04,'maximum_gap':.14}
        self.assertTrue(score(evaluation, actor, criteria)['success'])
        for changes in ({'wall_contact':True},{'travel_x':0},{'rest_ticks':0},{'minimum_gap_x':-.001},{'valid':False}):
            self.assertFalse(score(evaluation|changes, actor, criteria)['success'])


if __name__=='__main__':
    unittest.main()
