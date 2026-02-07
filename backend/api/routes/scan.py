"""
Scan management endpoints
"""
from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, Query
from models.schemas import (
    ScanConfigRequest,
    ScanResponse,
    ScanStatusResponse,
    ScanStatus,
    ScanResult,
    ScanHistoryResponse,
    ScanHistoryItem,
    PaginationMeta,
    ScanSortField,
    SortOrder,
)
from services.garak_wrapper import garak_wrapper
from datetime import datetime
from typing import Optional
import asyncio
import logging
import math

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/start", response_model=ScanResponse)
async def start_scan(config: ScanConfigRequest):
    """
    Start a new garak vulnerability scan

    Args:
        config: Scan configuration

    Returns:
        ScanResponse with scan_id and initial status
    """
    try:
        # Validate garak is installed
        if not garak_wrapper.check_garak_installed():
            raise HTTPException(
                status_code=500,
                detail="Garak is not installed or not accessible"
            )

        # Start the scan
        scan_id = await garak_wrapper.start_scan(config)

        return ScanResponse(
            scan_id=scan_id,
            status=ScanStatus.PENDING,
            message="Scan initiated successfully",
            created_at=datetime.now().isoformat()
        )

    except Exception as e:
        logger.error(f"Error starting scan: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{scan_id}/status", response_model=ScanStatusResponse)
async def get_scan_status(scan_id: str):
    """
    Get current status of a scan

    Args:
        scan_id: Unique scan identifier

    Returns:
        ScanStatusResponse with current status and progress
    """
    scan_info = garak_wrapper.get_scan_status(scan_id)

    if not scan_info:
        raise HTTPException(status_code=404, detail=f"Scan {scan_id} not found")

    return ScanStatusResponse(
        scan_id=scan_info['scan_id'],
        status=scan_info['status'],
        progress=scan_info['progress'],
        current_probe=scan_info.get('current_probe'),
        completed_probes=scan_info.get('completed_probes', 0),
        total_probes=scan_info.get('total_probes', 0),
        passed=scan_info.get('passed', 0),
        failed=scan_info.get('failed', 0),
        error_message=scan_info.get('error_message')
    )


@router.delete("/{scan_id}/cancel")
async def cancel_scan(scan_id: str):
    """
    Cancel a running scan

    Args:
        scan_id: Unique scan identifier

    Returns:
        Success message
    """
    success = await garak_wrapper.cancel_scan(scan_id)

    if not success:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel scan {scan_id}. It may not exist or already completed."
        )

    return {"message": f"Scan {scan_id} cancelled successfully"}


@router.delete("/{scan_id}")
async def delete_scan(scan_id: str):
    """
    Delete a scan and all its associated reports

    Args:
        scan_id: Unique scan identifier

    Returns:
        Success message
    """
    success = garak_wrapper.delete_scan(scan_id)

    if not success:
        raise HTTPException(
            status_code=404,
            detail=f"Scan {scan_id} not found or could not be deleted."
        )

    return {"message": f"Scan {scan_id} deleted successfully"}


@router.get("/history", response_model=ScanHistoryResponse)
async def get_scan_history(
    page: int = Query(1, ge=1, description="Page number (1-indexed)"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page (max 100)"),
    sort_by: ScanSortField = Query(ScanSortField.STARTED_AT, description="Field to sort by"),
    sort_order: SortOrder = Query(SortOrder.DESC, description="Sort order"),
    status: Optional[str] = Query(None, description="Filter by status (completed, running, failed, cancelled)"),
    search: Optional[str] = Query(None, description="Search by target name or scan ID"),
):
    """
    Get paginated list of all scans (active and completed)

    Args:
        page: Page number (1-indexed)
        page_size: Number of items per page (max 100)
        sort_by: Field to sort by
        sort_order: Sort order (asc or desc)
        status: Optional status filter
        search: Optional search query for target name or scan ID

    Returns:
        Paginated list of scan information
    """
    # Get all scans
    all_scans = garak_wrapper.get_all_scans()

    # Apply status filter
    if status:
        status_lower = status.lower()
        all_scans = [s for s in all_scans if s.get('status', '').lower() == status_lower]

    # Apply search filter
    if search:
        search_lower = search.lower()
        all_scans = [
            s for s in all_scans
            if search_lower in s.get('target_name', '').lower()
            or search_lower in s.get('scan_id', '').lower()
            or search_lower in s.get('target_type', '').lower()
        ]

    # Sort scans
    def get_sort_key(scan):
        if sort_by == ScanSortField.STARTED_AT:
            return scan.get('started_at', '') or ''
        elif sort_by == ScanSortField.COMPLETED_AT:
            return scan.get('completed_at', '') or ''
        elif sort_by == ScanSortField.STATUS:
            return scan.get('status', '') or ''
        elif sort_by == ScanSortField.TARGET_NAME:
            return scan.get('target_name', '') or ''
        elif sort_by == ScanSortField.PASS_RATE:
            passed = scan.get('passed', 0)
            failed = scan.get('failed', 0)
            total = passed + failed
            return (passed / total * 100) if total > 0 else 0
        return ''

    reverse_sort = sort_order == SortOrder.DESC
    all_scans.sort(key=get_sort_key, reverse=reverse_sort)

    # Calculate pagination
    total_items = len(all_scans)
    total_pages = math.ceil(total_items / page_size) if total_items > 0 else 1
    start_idx = (page - 1) * page_size
    end_idx = start_idx + page_size

    # Get page slice
    page_scans = all_scans[start_idx:end_idx]

    # Convert to response model
    scan_items = [
        ScanHistoryItem(
            scan_id=s.get('scan_id', ''),
            status=s.get('status', 'unknown'),
            target_type=s.get('target_type'),
            target_name=s.get('target_name'),
            started_at=s.get('started_at'),
            completed_at=s.get('completed_at'),
            passed=s.get('passed', 0),
            failed=s.get('failed', 0),
            total_tests=s.get('passed', 0) + s.get('failed', 0),
            progress=s.get('progress', 0.0),
            html_report_path=s.get('html_report_path'),
            jsonl_report_path=s.get('jsonl_report_path'),
        )
        for s in page_scans
    ]

    pagination = PaginationMeta(
        page=page,
        page_size=page_size,
        total_items=total_items,
        total_pages=total_pages,
        has_next=page < total_pages,
        has_previous=page > 1,
    )

    return ScanHistoryResponse(
        scans=scan_items,
        pagination=pagination,
        total_count=total_items,
    )


@router.get("/{scan_id}/results", response_model=ScanResult)
async def get_scan_results(scan_id: str):
    """
    Get detailed scan results including probe-level information

    Args:
        scan_id: Unique scan identifier

    Returns:
        Detailed scan results with probe breakdown
    """
    scan_info = garak_wrapper.get_scan_status(scan_id)

    if not scan_info:
        raise HTTPException(status_code=404, detail=f"Scan {scan_id} not found")

    # Get full scan details
    full_results = garak_wrapper.get_scan_results(scan_id)

    if not full_results:
        raise HTTPException(
            status_code=404,
            detail=f"Results not available for scan {scan_id}"
        )

    return full_results


@router.get("/{scan_id}/report/html")
async def get_html_report(scan_id: str):
    """
    Get HTML report for a scan

    Args:
        scan_id: Unique scan identifier

    Returns:
        HTML report file
    """
    from fastapi.responses import FileResponse
    from pathlib import Path

    scan_info = garak_wrapper.get_scan_status(scan_id)

    if not scan_info:
        raise HTTPException(status_code=404, detail=f"Scan {scan_id} not found")

    html_report_path = scan_info.get('html_report_path')

    if not html_report_path:
        raise HTTPException(
            status_code=404,
            detail="HTML report not available for this scan"
        )

    # Check if file exists
    report_file = Path(html_report_path)
    if not report_file.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Report file not found: {html_report_path}"
        )

    return FileResponse(
        path=str(report_file),
        media_type="text/html",
        filename=f"scan_{scan_id}_report.html"
    )


@router.get("/{scan_id}/report/detailed")
async def get_detailed_report(scan_id: str):
    """
    Get detailed HTML report for a scan

    Args:
        scan_id: Unique scan identifier

    Returns:
        HTML report content
    """
    from fastapi.responses import HTMLResponse
    from pathlib import Path

    scan_info = garak_wrapper.get_scan_status(scan_id)

    if not scan_info:
        raise HTTPException(status_code=404, detail=f"Scan {scan_id} not found")

    html_report_path = scan_info.get('html_report_path')

    if not html_report_path:
        raise HTTPException(
            status_code=404,
            detail="Detailed report not available for this scan"
        )

    # Check if file exists
    report_file = Path(html_report_path)
    if not report_file.exists():
        raise HTTPException(
            status_code=404,
            detail=f"Report file not found: {html_report_path}"
        )

    # Read and return HTML content
    try:
        with open(report_file, 'r', encoding='utf-8') as f:
            html_content = f.read()

        return HTMLResponse(content=html_content)

    except Exception as e:
        logger.error(f"Error reading HTML report: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Error reading report: {str(e)}"
        )


@router.websocket("/{scan_id}/progress")
async def scan_progress_websocket(websocket: WebSocket, scan_id: str):
    """
    WebSocket endpoint for real-time scan progress updates

    Args:
        websocket: WebSocket connection
        scan_id: Unique scan identifier
    """
    await websocket.accept()

    try:
        while True:
            scan_info = garak_wrapper.get_scan_status(scan_id)

            if not scan_info:
                await websocket.send_json({
                    "error": f"Scan {scan_id} not found"
                })
                break

            # Send current status
            await websocket.send_json({
                "scan_id": scan_info['scan_id'],
                "status": scan_info['status'],
                "progress": scan_info['progress'],
                "current_probe": scan_info.get('current_probe'),
                "completed_probes": scan_info.get('completed_probes', 0),
                "total_probes": scan_info.get('total_probes', 0),
                "current_iteration": scan_info.get('current_iteration', 0),
                "total_iterations": scan_info.get('total_iterations', 0),
                "passed": scan_info.get('passed', 0),
                "failed": scan_info.get('failed', 0),
                "elapsed_time": scan_info.get('elapsed_time'),
                "estimated_remaining": scan_info.get('estimated_remaining'),
                "timestamp": datetime.now().isoformat()
            })

            # If scan completed or failed, send one final update with complete results, then close
            if scan_info['status'] in [ScanStatus.COMPLETED, ScanStatus.FAILED, ScanStatus.CANCELLED]:
                # Send final update with all results
                await websocket.send_json({
                    "scan_id": scan_info['scan_id'],
                    "status": scan_info['status'],
                    "progress": scan_info['progress'],
                    "current_probe": scan_info.get('current_probe'),
                    "completed_probes": scan_info.get('completed_probes', 0),
                    "total_probes": scan_info.get('total_probes', 0),
                    "current_iteration": scan_info.get('current_iteration', 0),
                    "total_iterations": scan_info.get('total_iterations', 0),
                    "passed": scan_info.get('passed', 0),
                    "failed": scan_info.get('failed', 0),
                    "elapsed_time": scan_info.get('elapsed_time'),
                    "estimated_remaining": scan_info.get('estimated_remaining'),
                    "error_message": scan_info.get('error_message'),
                    "message": "Scan finished",
                    "final_status": scan_info['status'],
                    "timestamp": datetime.now().isoformat()
                })
                break

            # Wait before sending next update
            await asyncio.sleep(1)

    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected for scan {scan_id}")
    except Exception as e:
        logger.error(f"WebSocket error for scan {scan_id}: {e}")
        try:
            await websocket.send_json({"error": str(e)})
        except:
            pass
