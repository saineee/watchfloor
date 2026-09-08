function AlertRow({ alert }) {

    return (
        <li>
            {alert.id} - {alert.device_name} - {alert.severity} - {alert.status}
        </li>
    )
}

export default AlertRow
