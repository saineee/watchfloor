import {useState} from 'react'

function AlertRow({alert, onTriaged}) {
    const [triaging, setTriaging] = useState(false)

    const triage = async () => {
        setTriaging(true)
        try {
            const res = await fetch(`http://localhost:8000/alerts/${alert.id}/triage`, {
                method: 'POST', credentials: 'include'
            })
            if (!res.ok) {
                throw new Error(`HTTP error! status: ${res.status}`);
            }
            const data = await res.json()
            console.log(`Triage successful for alert: ${alert.id}`);
            onTriaged(data)
        } catch (err) {
            console.log('Triage failed: ', err)
        } finally {
            setTriaging(false)
        }
    }

    return (
        <>
            <li>
                {alert.id} - {alert.device_name} - {alert.severity} - {alert.status} - {alert.summary}
                <button type="button" onClick={triage}
                        disabled={triaging}>{triaging ? 'Triaging...' : 'Triage'}</button>
            </li>
        </>
    )
}

export default AlertRow
