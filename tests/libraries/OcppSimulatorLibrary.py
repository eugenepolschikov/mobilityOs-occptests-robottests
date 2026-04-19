from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Tuple


def _parse_ts(timestamp: str) -> datetime:
    return datetime.fromisoformat(timestamp.replace("Z", "+00:00"))


@dataclass
class Session:
    transaction_id: str
    connector_id: int
    meter_start: int
    start_timestamp: str
    meter_values: List[Tuple[str, int]] = field(default_factory=list)
    meter_stop: Optional[int] = None
    stop_timestamp: Optional[str] = None
    state: str = "OPEN"
    anomaly: Optional[str] = None
    duplicate_starts: int = 0


class OcppSimulatorLibrary:
    """In-memory OCPP session simulator for Robot tests."""

    def __init__(self) -> None:
        self.reset_simulator_state()

    def reset_simulator_state(self) -> None:
        self._sessions: Dict[str, Session] = {}
        self._active_by_connector: Dict[int, str] = {}
        self._rejected_stops: List[str] = []

    def send_start_transaction(
        self,
        transaction_id: str,
        connector_id: int,
        meter_start: int,
        timestamp: str,
    ) -> str:
        existing = self._sessions.get(transaction_id)
        if existing:
            existing.duplicate_starts += 1
            return "NO_OP_DUPLICATE"

        if connector_id in self._active_by_connector:
            return "REJECTED_CONNECTOR_BUSY"

        session = Session(
            transaction_id=transaction_id,
            connector_id=connector_id,
            meter_start=meter_start,
            start_timestamp=timestamp,
        )
        self._sessions[transaction_id] = session
        self._active_by_connector[connector_id] = transaction_id
        return "ACCEPTED"

    def send_meter_value(self, transaction_id: str, meter_value: int, timestamp: str) -> str:
        session = self._sessions.get(transaction_id)
        if not session:
            return "REJECTED_NO_SESSION"
        session.meter_values.append((timestamp, meter_value))
        return "ACCEPTED"

    def send_stop_transaction(
        self, transaction_id: str, meter_stop: int, timestamp: str
    ) -> str:
        session = self._sessions.get(transaction_id)
        if not session:
            self._rejected_stops.append(transaction_id)
            return "REJECTED_NO_START"

        session.meter_stop = meter_stop
        session.stop_timestamp = timestamp
        self._finalize_if_possible(session)
        self._active_by_connector.pop(session.connector_id, None)
        return "ACCEPTED"

    def _finalize_if_possible(self, session: Session) -> None:
        if session.meter_stop is None:
            return

        all_points: List[Tuple[str, int]] = [
            (session.start_timestamp, session.meter_start),
            *session.meter_values,
            (session.stop_timestamp or session.start_timestamp, session.meter_stop),
        ]
        all_points_sorted = sorted(all_points, key=lambda p: _parse_ts(p[0]))
        values = [point[1] for point in all_points_sorted]

        for idx in range(1, len(values)):
            if values[idx] < values[idx - 1]:
                session.state = "FAULTED"
                session.anomaly = "DECREASING_METER_VALUE"
                return

        session.state = "COMPLETED"
        session.anomaly = None

    def get_session_state(self, transaction_id: str) -> str:
        session = self._sessions[transaction_id]
        return session.state

    def get_session_energy_wh(self, transaction_id: str) -> int:
        session = self._sessions[transaction_id]
        points: List[Tuple[str, int]] = [
            (session.start_timestamp, session.meter_start),
            *session.meter_values,
        ]
        if session.meter_stop is not None:
            points.append((session.stop_timestamp or session.start_timestamp, session.meter_stop))
        points_sorted = sorted(points, key=lambda p: _parse_ts(p[0]))
        return points_sorted[-1][1] - points_sorted[0][1]

    def get_open_session_count_for_connector(self, connector_id: int) -> int:
        return 1 if connector_id in self._active_by_connector else 0

    def get_duplicate_start_count(self, transaction_id: str) -> int:
        session = self._sessions[transaction_id]
        return session.duplicate_starts

    def get_session_anomaly(self, transaction_id: str) -> str:
        session = self._sessions[transaction_id]
        return session.anomaly or ""
