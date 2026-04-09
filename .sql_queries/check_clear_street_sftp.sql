select distinct                                                                                                                                                                                                                                                         
    to_char(trade_date_from_sftp::DATE, 'Dy Mon-DD') as trade_date                                                       
    ,to_char(sftp_upload_timestamp, 'Dy Mon-DD HH12:MI AM') as released_from_clear_street
    ,to_char(created_at, 'Dy Mon-DD HH12:MI AM') as downloaded_at

from clear_street.helios_transactions_v2_2026_feb_23

WHERE
    trade_date_from_sftp::DATE >= current_date - 7

ORDER BY trade_date DESC