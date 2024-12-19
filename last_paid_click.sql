with tab1 as (
    select
        s.visitor_id,
        date(s.visit_date) as visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.closing_reason,
        l.status_id,
        sum(l.amount) over (partition by l.visitor_id) as amount,
        row_number()
            over (
                partition by s.visitor_id
                order by s.visit_date desc
            )
        as rn
    from sessions as s
    left join leads as l 
    on 
        s.visitor_id = l.visitor_id 
        and s.visit_date <= l.created_at

)

select
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
from tab1
where
    rn = 1
    and utm_medium in ('cpc', 'cpm', 'cpa', 'cpp', 'tg', 'youtube', 'social')
order by
    amount desc nulls last,
    visit_date asc,
    utm_source asc,
    utm_medium asc,
    utm_campaign asc
limit 10;
