Connect-VIServer -Server "{{ server }}" -Protocol https -User "{{ username }}" -Password "{{ password }}"
$networks = Get-VirtualNetwork -NetworkType Distributed |
$networks
