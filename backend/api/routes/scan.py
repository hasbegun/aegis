"""
Scan management endpoints
"""
from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from models.schemas import (
    ScanConfigRequest,
    ScanResponse,
    ScanStatusResponse,
    ScanStatus,
    ScanResult
)
from services.garak_wrapper import garak_wrapper
from datetime import datetime
import asyncio
import logging

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


@router.get("/history")
async def get_scan_history():
    """
    Get list of all scans (active and completed)

    Returns:
        List of scan information
    """
    scans = garak_wrapper.get_all_scans()
    return {
        "scans": scans,
        "total_count": len(scans)
    }


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
