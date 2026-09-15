import {useState} from 'react'
import {API_URL} from './config.js'

const ALLOWED_TRANSITIONS = {
    "new": ["resolved", "in_progress"],
    "in_progress": ["escalated", "resolved"],
    "escalated": ["in_progress", "resolved"],
    "resolved": []
}

function AlertRow({alert, onAlertUpdated}) {
    const [triaging, setTriaging] = useState(false)
    const [updating, setUpdating] = useState(false)

    const triage = async () => {
        setTriaging(true)
        try {
            const res = await fetch(`${API_URL}/alerts/${alert.id}/triage`, {
                method: 'POST', credentials: 'include'
            })
            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`);
            }
            const data = await res.json()
            console.log(`Triage successful for alert: ${alert.id}`);
            onAlertUpdated(data)
        } catch (err) {
            console.error('Triage failed: ', err)
        } finally {
            setTriaging(false)
        }
    }

    const updateStatus = async (newStatus) => {
        setUpdating(true)
        try {
            const res = await fetch(`${API_URL}/alerts/${alert.id}`, {
                method: 'PATCH',
                credentials: 'include',
                headers: {"Content-Type": "application/json"},
                body: JSON.stringify({status: newStatus})
            })
            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`)
            }
            const data = await res.json()
            console.log(`Status change successful for alert ${alert.id}`)
            onAlertUpdated(data)
        } catch (err) {
            console.error('Status change failed: ', err)
        } finally {
            setUpdating(false)
        }
    }
    const next = ALLOWED_TRANSITIONS[alert.status]

    return (
        <>
            <li>
                {alert.id} - {alert.device_name} - {alert.severity} - <select value={alert.status}
                                                                              onChange={(e) => updateStatus(e.target.value)}
                                                                              disabled={updating || next.length === 0}>
                {[alert.status, ...next].map((s) => (
                    <option key={s} value={s}>{s}</option>
                ))}
            </select> - {alert.summary}
                <button type="button" onClick={triage}
                        disabled={triaging}>{triaging ? 'Triaging...' : 'Triage'}</button>
            </li>
        </>
    )
}

export default AlertRow
