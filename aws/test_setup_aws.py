import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_settlements import make_event
from setup_aws import firehose_request, ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('id-palm-oil-trading', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'id-palm-oil-trading-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'ID_PALM_OIL_TRADING_S3_INT')
        self.assertEqual(n['firehose_stream'], 'id-palm-oil-trading-settlements')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_firehose_request_matches_aws_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('id-palm-oil-trading', '123456789012', 'us-west-2')
        req = firehose_request(n, n['bucket'], 'arn:aws:iam::123456789012:role/id-palm-oil-trading-firehose-s3')
        model = botocore.session.get_session().get_service_model('firehose')
        validate_parameters(req, model.operation_model('CreateDeliveryStream').input_shape)
        dest = req['ExtendedS3DestinationConfiguration']
        self.assertEqual(dest['Prefix'], 'settlements/')
        self.assertFalse(dest['ErrorOutputPrefix'].startswith('settlements/'))

    def test_settlement_event_matches_pipe_columns(self):
        import random
        rng = random.Random(7)
        events = [make_event(rng) for _ in range(200)]
        self.assertEqual(set(events[0]), {'counterparty_id', 'event_ts', 'amount_usd', 'days_overdue', 'status', 'sent_ms'})
        for event in events:
            self.assertRegex(event['counterparty_id'], r'^BUY-0(0\d\d|1[01]\d)$')
            self.assertIn(event['status'], ('LATE', 'SETTLED'))
            self.assertEqual(event['status'] == 'SETTLED', event['days_overdue'] == 0)


if __name__ == '__main__':
    unittest.main()
